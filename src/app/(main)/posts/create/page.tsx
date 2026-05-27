'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/hooks/useAuth'
import { PostForm } from '@/components/post/PostForm'
import { createPost, uploadPostImage } from '@/lib/supabase/queries'
import { upsertProfile } from '@/lib/supabase/queries'
import type { PostCategory } from '@/types'

export default function CreatePostPage() {
  const router = useRouter()
  const { user, loading } = useAuth()

  useEffect(() => {
    if (!loading && !user) router.replace('/login')
  }, [user, loading, router])

  async function handleSubmit({
    category,
    content,
    imageFile,
  }: {
    category: PostCategory
    content: string
    imageFile: File | null
  }) {
    if (!user) return

    await upsertProfile({
      id: user.id,
      displayName: user.user_metadata?.full_name ?? user.email ?? '익명',
      email: user.email ?? '',
      photoUrl: user.user_metadata?.avatar_url ?? null,
    })

    const { data: post, error } = await createPost({
      authorId: user.id,
      category,
      content,
      imageUrls: [],
    })

    if (error || !post) return

    let imageUrls: string[] = []
    if (imageFile) {
      const url = await uploadPostImage(imageFile, post.id)
      imageUrls = [url]
      await import('@/lib/supabase/client').then(({ supabase }) =>
        supabase.from('posts').update({ image_urls: imageUrls }).eq('id', post.id)
      )
    }

    router.push('/')
  }

  if (loading || !user) return null

  return (
    <div>
      <h1 className="text-lg font-bold text-gray-900 mb-6">글 쓰기</h1>
      <PostForm onSubmit={handleSubmit} />
    </div>
  )
}
