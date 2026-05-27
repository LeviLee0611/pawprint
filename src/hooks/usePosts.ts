'use client'

import { useState, useEffect } from 'react'
import { fetchPosts } from '@/lib/supabase/queries'
import type { Post } from '@/types'
import { POSTS_PER_PAGE } from '@/constants'

function mapPost(row: Record<string, unknown>): Post {
  const profiles = row.profiles as { display_name: string; photo_url?: string | null } | null
  const likes = (row.post_likes as { user_id: string }[]) ?? []
  return {
    id: row.id as string,
    authorId: row.author_id as string,
    authorName: profiles?.display_name ?? '알 수 없음',
    authorPhotoUrl: profiles?.photo_url ?? null,
    category: row.category as Post['category'],
    content: row.content as string,
    imageUrls: (row.image_urls as string[]) ?? [],
    likeCount: row.like_count as number,
    likeUserIds: likes.map((l) => l.user_id),
    commentCount: row.comment_count as number,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
  }
}

export function usePosts() {
  const [posts, setPosts] = useState<Post[]>([])
  const [loading, setLoading] = useState(true)
  const [hasMore, setHasMore] = useState(true)
  const [offset, setOffset] = useState(0)

  async function load(from: number) {
    setLoading(true)
    const { data } = await fetchPosts(from)
    const newPosts = (data ?? []).map(mapPost)
    setPosts((prev) => (from === 0 ? newPosts : [...prev, ...newPosts]))
    setHasMore(newPosts.length === POSTS_PER_PAGE)
    setLoading(false)
  }

  useEffect(() => { load(0) }, [])

  function loadMore() {
    const next = offset + POSTS_PER_PAGE
    setOffset(next)
    load(next)
  }

  return { posts, loading, hasMore, loadMore }
}

export { mapPost }
