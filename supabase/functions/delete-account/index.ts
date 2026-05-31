import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // 유저 검증 (anon key + 유저 토큰)
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const userId = user.id

  // 관리자 클라이언트 (service role)
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    // 1. Storage 파일 정리 — pet-photos
    const { data: petPhotos } = await adminClient.storage
      .from('pet-photos')
      .list(userId)
    if (petPhotos && petPhotos.length > 0) {
      const paths = petPhotos.map((f: { name: string }) => `${userId}/${f.name}`)
      await adminClient.storage.from('pet-photos').remove(paths)
    }

    // 2. Storage 파일 정리 — post-images
    const { data: postImages } = await adminClient.storage
      .from('post-images')
      .list(userId)
    if (postImages && postImages.length > 0) {
      const paths = postImages.map((f: { name: string }) => `${userId}/${f.name}`)
      await adminClient.storage.from('post-images').remove(paths)
    }

    // 3. auth.users 삭제 → profiles cascade → pets, records, posts, comments, likes 전부 삭제
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId)
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
