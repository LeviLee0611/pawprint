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
      console.error(`FCM error: ${err}`)
      return false
    }
    return true
  } catch (e) {
    console.error(`FCM exception: ${e}`)
    return false
  }
}

serve(async (req) => {
  // CRON_SECRET으로 외부 무단 호출 방지
  const cronSecret = Deno.env.get('CRON_SECRET')
  if (cronSecret) {
    const authHeader = req.headers.get('Authorization') ?? ''
    if (authHeader !== `Bearer ${cronSecret}`) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
    const projectId: string = sa.project_id
    const accessToken = await getAccessToken(sa)

    // KST 기준 오늘 월/일
    const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000)
    const mm = kstNow.getUTCMonth() + 1
    const dd = kstNow.getUTCDate()
    const todayStr = kstNow.toISOString().split('T')[0]

    // extract() 기반 RPC로 date 타입 안전하게 조회
    const { data: pets, error: pErr } = await supabase.rpc('get_birthday_pets', {
      p_month: mm,
      p_day: dd,
    })

    if (pErr) throw pErr
    if (!pets || pets.length === 0) {
      return new Response(JSON.stringify({ sent: 0, date: todayStr }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const ownerIds = [...new Set(pets.map((p: { owner_id: string }) => p.owner_id))]
    const { data: tokens, error: tErr } = await supabase
      .from('fcm_tokens')
      .select('owner_id, token')
      .in('owner_id', ownerIds)

    if (tErr) throw tErr

    const tokenMap: Record<string, string[]> = {}
    for (const t of tokens ?? []) {
      if (!tokenMap[t.owner_id]) tokenMap[t.owner_id] = []
      tokenMap[t.owner_id].push(t.token)
    }

    let sent = 0
    for (const pet of pets as Array<{ id: string; name: string; type: string; owner_id: string }>) {
      // 당일 이미 발송했으면 건너뜀 (중복 방지)
      const { error: dupErr } = await supabase
        .from('birthday_notifications_sent')
        .insert({ owner_id: pet.owner_id, pet_id: pet.id, sent_date: todayStr })

      if (dupErr) {
        // unique 제약 위반 = 이미 발송됨
        console.log(`Birthday already sent for pet ${pet.id} on ${todayStr}`)
        continue
      }

      const fcmTokens = tokenMap[pet.owner_id] ?? []
      const emoji = pet.type === 'cat' ? '🐱' : '🐶'
      const title = `${emoji} ${pet.name}의 생일이에요!`
      const body = `오늘은 ${pet.name}의 특별한 날이에요. 축하해주세요 🎂`

      for (const token of fcmTokens) {
        const ok = await sendFcm(token, title, body, projectId, accessToken)
        if (ok) sent++
      }
    }

    return new Response(JSON.stringify({ sent, date: todayStr }), {
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
