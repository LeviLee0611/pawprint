import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function base64url(data: ArrayBuffer | string): string {
  const bytes =
    typeof data === 'string'
      ? new TextEncoder().encode(data)
      : new Uint8Array(data)
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const binary = atob(b64)
  const buf = new ArrayBuffer(binary.length)
  const view = new Uint8Array(buf)
  for (let i = 0; i < binary.length; i++) view[i] = binary.charCodeAt(i)
  return buf
}

// deno-lint-ignore no-explicit-any
async function getAccessToken(sa: Record<string, any>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64url(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    })
  )
  const signingInput = `${header}.${payload}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput)
  )
  const jwt = `${signingInput}.${base64url(sig)}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const json = await res.json()
  if (!json.access_token) throw new Error(`Token error: ${JSON.stringify(json)}`)
  return json.access_token
}

// 성공하면 true, 실패하면 false 반환
async function sendFcm(
  fcmToken: string,
  title: string,
  body: string,
  projectId: string,
  accessToken: string
): Promise<boolean> {
  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: { token: fcmToken, notification: { title, body } },
        }),
      }
    )
    if (!res.ok) {
      const err = await res.text()
      console.error(`FCM error for token ${fcmToken.slice(0, 10)}...: ${err}`)
      return false
    }
    return true
  } catch (e) {
    console.error(`FCM exception: ${e}`)
    return false
  }
}

serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
    const projectId: string = sa.project_id
    const accessToken = await getAccessToken(sa)

    // KST 기준 오늘 날짜 (UTC+9)
    const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000)
    const today = kstNow.toISOString().split('T')[0]

    const { data: reminders, error: rErr } = await supabase
      .from('reminders')
      .select('id, title, owner_id')
      .eq('remind_at', today)
      .eq('sent', false)

    if (rErr) throw rErr
    if (!reminders || reminders.length === 0) {
      return new Response(JSON.stringify({ sent: 0, date: today }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const ownerIds = [...new Set(reminders.map((r) => r.owner_id))]
    const { data: profiles, error: pErr } = await supabase
      .from('profiles')
      .select('id, fcm_token')
      .in('id', ownerIds)

    if (pErr) throw pErr

    const tokenMap = Object.fromEntries(
      (profiles ?? [])
        .filter((p) => p.fcm_token)
        .map((p) => [p.id, p.fcm_token as string])
    )

    const sentIds: string[] = []
    for (const r of reminders) {
      const fcmToken = tokenMap[r.owner_id]
      if (!fcmToken) continue
      const ok = await sendFcm(fcmToken, '예방접종 알림 🐾', r.title, projectId, accessToken)
      if (ok) sentIds.push(r.id)
    }

    if (sentIds.length > 0) {
      await supabase.from('reminders').update({ sent: true }).in('id', sentIds)
    }

    return new Response(JSON.stringify({ sent: sentIds.length, date: today }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
