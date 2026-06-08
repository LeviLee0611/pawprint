import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const VISION_API_KEY = Deno.env.get('GOOGLE_VISION_API_KEY')!
const UNSAFE = new Set(['LIKELY', 'VERY_LIKELY'])
const MAX_IMAGES = 10

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let body: { imageUrls?: unknown }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), { status: 400 })
  }

  const { imageUrls } = body

  if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
    return json({ safe: true })
  }

  if (imageUrls.length > MAX_IMAGES) {
    return new Response(JSON.stringify({ error: `최대 ${MAX_IMAGES}장까지 검사 가능해요` }), { status: 400 })
  }

  const validUrls = imageUrls.filter((u): u is string => typeof u === 'string' && u.startsWith('http'))
  if (validUrls.length === 0) {
    return json({ safe: true })
  }

  const requests = validUrls.map((url: string) => ({
    image: { source: { imageUri: url } },
    features: [{ type: 'SAFE_SEARCH_DETECTION' }],
  }))

  let res: Response
  try {
    res = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${VISION_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requests }),
      }
    )
  } catch (e) {
    console.error('Vision API network error:', e)
    // API 호출 자체 실패 시 통과 (서비스 중단 방지), 단 로그 남김
    return json({ safe: true, warning: 'moderation_unavailable' })
  }

  if (!res.ok) {
    const errText = await res.text().catch(() => '')
    console.error(`Vision API error ${res.status}:`, errText)
    return json({ safe: true, warning: 'moderation_unavailable' })
  }

  const data = await res.json()

  for (const result of data.responses ?? []) {
    if (result.error) {
      console.error('Vision result error:', result.error)
      continue
    }
    const s = result.safeSearchAnnotation
    if (!s) continue
    if (UNSAFE.has(s.adult) || UNSAFE.has(s.violence)) {
      return json({ safe: false, reason: '부적절한 콘텐츠가 감지됐어요' })
    }
  }

  return json({ safe: true })
})

function json(data: unknown) {
  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' },
  })
}
