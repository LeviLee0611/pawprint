import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── FCM helpers (send-reminders와 동일 패턴) ────────────────

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
  return json.access_token as string
}

async function sendFcm(
  fcmToken: string,
  title: string,
  body: string,
  projectId: string,
  accessToken: string,
  data?: Record<string, string>
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
          message: {
            token: fcmToken,
            notification: { title, body },
            ...(data && { data }),
          },
        }),
      }
    )
    if (!res.ok) {
      console.error(`FCM error: ${await res.text()}`)
      return false
    }
    return true
  } catch (e) {
    console.error(`FCM exception: ${e}`)
    return false
  }
}

// ── 메인 핸들러 ────────────────────────────────────────────

serve(async (req) => {
  try {
    const payload = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
    const projectId: string = sa.project_id
    const accessToken = await getAccessToken(sa)

    // ── 케이스 1: notifications INSERT (좋아요 / 댓글 / 팔로우) ──
    if (payload.type === 'INSERT' && payload.table === 'notifications') {
      const record = payload.record
      const notifType: string = record.type // 'like' | 'comment' | 'follow'

      if (!['like', 'comment', 'follow'].includes(notifType)) {
        return ok({ skipped: 'unknown type' })
      }

      // 알림 설정 확인
      const { data: settings } = await supabase
        .from('notification_settings')
        .select('like_setting, comment_setting, follow_enabled')
        .eq('user_id', record.recipient_id)
        .maybeSingle()

      // 팔로우 알림 — boolean
      if (notifType === 'follow') {
        const enabled: boolean = settings?.follow_enabled ?? true
        if (!enabled) return ok({ skipped: 'disabled by user' })
      }

      // 좋아요/댓글 — 3단계 (everyone | following_only | off)
      if (notifType === 'like' || notifType === 'comment') {
        const settingVal: string = notifType === 'like'
          ? (settings?.like_setting ?? 'everyone')
          : (settings?.comment_setting ?? 'everyone')

        if (settingVal === 'off') return ok({ skipped: 'disabled by user' })

        if (settingVal === 'following_only') {
          // 수신자가 발신자를 팔로우하는지 확인
          const { data: followCheck } = await supabase
            .from('follows')
            .select('id')
            .eq('follower_id', record.recipient_id)
            .eq('following_id', record.actor_id)
            .maybeSingle()
          if (!followCheck) return ok({ skipped: 'actor not followed by recipient' })
        }
      }

      // FCM 토큰 조회 (멀티 디바이스)
      const { data: tokenRows } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('owner_id', record.recipient_id)
      if (!tokenRows || tokenRows.length === 0) return ok({ skipped: 'no token' })

      // 발신자 이름 조회
      const { data: actor } = await supabase
        .from('profiles')
        .select('display_name')
        .eq('id', record.actor_id)
        .maybeSingle()
      const actorName: string = actor?.display_name ?? '누군가'

      const messages: Record<string, { title: string; body: string }> = {
        like:    { title: '댕냥스토리', body: `${actorName}님이 게시글을 좋아합니다 ❤️` },
        comment: { title: '댕냥스토리', body: `${actorName}님이 댓글을 달았어요 💬` },
        follow:  { title: '댕냥스토리', body: `${actorName}님이 팔로우했어요 🐾` },
      }

      const results = await Promise.all(
        tokenRows.map((row: { token: string }) =>
          sendFcm(row.token, messages[notifType].title, messages[notifType].body, projectId, accessToken)
        )
      )
      return ok({ sent: results.filter(Boolean).length })
    }

    // ── 케이스 2: new_post (팔로워에게 새 게시글 알림) ──
    // payload: { trigger_type: 'new_post', post_owner_id, owner_name }
    if (payload.trigger_type === 'new_post') {
      // JWT에서 호출자 확인 — post_owner_id와 일치해야만 허용
      const authHeader = req.headers.get('Authorization') ?? ''
      const jwt = authHeader.replace('Bearer ', '')
      const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)
      if (authError || !user) {
        return new Response(JSON.stringify({ error: 'unauthorized' }), {
          status: 401, headers: { 'Content-Type': 'application/json' },
        })
      }
      if (user.id !== payload.post_owner_id) {
        return new Response(JSON.stringify({ error: 'forbidden' }), {
          status: 403, headers: { 'Content-Type': 'application/json' },
        })
      }

      const { post_owner_id, owner_name } = payload

      const { data: followers } = await supabase
        .from('follows')
        .select('follower_id')
        .eq('following_id', post_owner_id)
      if (!followers || followers.length === 0) return ok({ sent: 0 })

      const followerIds: string[] = followers.map(
        (f: { follower_id: string }) => f.follower_id
      )

      const [{ data: settingsRows }, { data: tokens }] = await Promise.all([
        supabase
          .from('notification_settings')
          .select('user_id, new_post_enabled')
          .in('user_id', followerIds),
        supabase
          .from('fcm_tokens')
          .select('owner_id, token')
          .in('owner_id', followerIds),
      ])

      const disabledSet = new Set(
        (settingsRows ?? [])
          .filter((s: { new_post_enabled: boolean }) => !s.new_post_enabled)
          .map((s: { user_id: string }) => s.user_id)
      )
      const tokenMap = Object.fromEntries(
        (tokens ?? []).map((t: { owner_id: string; token: string }) => [
          t.owner_id, t.token,
        ])
      )

      const title = '댕냥스토리'
      const body = `${owner_name ?? '누군가'}님이 새 글을 올렸어요 📸`

      let sent = 0
      for (const id of followerIds) {
        if (disabledSet.has(id) || !tokenMap[id]) continue
        if (await sendFcm(tokenMap[id], title, body, projectId, accessToken)) sent++
      }
      return ok({ sent })
    }

    // ── 케이스 3: reports INSERT (관리자에게 신고 알림) ──
    if (payload.type === 'INSERT' && payload.table === 'reports') {
      const record = payload.record
      const adminId = Deno.env.get('ADMIN_USER_ID')
      if (!adminId) return ok({ skipped: 'ADMIN_USER_ID not set' })

      const { data: adminTokens } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('owner_id', adminId)
      if (!adminTokens || adminTokens.length === 0) return ok({ skipped: 'no admin token' })

      const typeLabel = record.target_type === 'post' ? '게시글' : '댓글'
      const results = await Promise.all(
        adminTokens.map((row: { token: string }) =>
          sendFcm(row.token, '🚨 신고 접수', `${typeLabel} 신고가 들어왔어요 — ${record.reason}`, projectId, accessToken)
        )
      )
      return ok({ sent: results.filter(Boolean).length })
    }

    // ── 케이스 4: new_chat_message (채팅 상대방에게 메시지 알림) ──
    // payload: { trigger_type: 'new_chat_message', recipient_id, sender_name, post_title? }
    if (payload.trigger_type === 'new_chat_message') {
      const { recipient_id, sender_name, post_title } = payload

      // 멀티 디바이스: 유저가 여러 토큰을 가질 수 있으므로 전체 조회
      const { data: tokenRows } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('owner_id', recipient_id)
      if (!tokenRows || tokenRows.length === 0) return ok({ skipped: 'no token' })

      const body = post_title
        ? `${sender_name ?? '누군가'}: ${post_title}`
        : `${sender_name ?? '누군가'}님이 메시지를 보냈어요`

      const results = await Promise.all(
        tokenRows.map((row: { token: string }) =>
          sendFcm(row.token, '새 메시지 💬', body, projectId, accessToken, { type: 'chat' })
        )
      )
      return ok({ sent: results.filter(Boolean).length })
    }

    return ok({ skipped: 'unhandled trigger' })
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

function ok(body: unknown) {
  return new Response(JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json' },
  })
}
