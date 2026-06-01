import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Storage 파일을 페이지 단위로 전부 삭제 (100개씩)
async function deleteAllFiles(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  bucket: string,
  userId: string
): Promise<void> {
  const limit = 100
  let offset = 0

  while (true) {
    const { data, error } = await adminClient.storage
      .from(bucket)
      .list(userId, { limit, offset })

    if (error) throw new Error(`${bucket} 목록 조회 실패: ${error.message}`)
    if (!data || data.length === 0) break

    const paths = data.map((f: { name: string }) => `${userId}/${f.name}`)
    const { error: removeError } = await adminClient.storage.from(bucket).remove(paths)
    if (removeError) throw new Error(`${bucket} 파일 삭제 실패: ${removeError.message}`)

    if (data.length < limit) break
    offset += limit
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // 유저 검증
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const userId = user.id

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    // 1. Storage 파일 삭제 — 실패 시 계정 삭제 진행 안 함
    await deleteAllFiles(adminClient, 'pet-photos', userId)
    await deleteAllFiles(adminClient, 'post-images', userId)

    // 2. auth.users 삭제 → profiles cascade → pets, records, posts 등 전부 삭제
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId)
    if (deleteError) throw new Error(deleteError.message)

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
