'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase/client'
import { fetchComments } from '@/lib/supabase/queries'
import type { Comment } from '@/types'

function mapComment(row: Record<string, unknown>): Comment {
  const profiles = row.profiles as { display_name: string; photo_url?: string | null } | null
  return {
    id: row.id as string,
    postId: row.post_id as string,
    authorId: row.author_id as string,
    authorName: profiles?.display_name ?? '알 수 없음',
    authorPhotoUrl: profiles?.photo_url ?? null,
    content: row.content as string,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
  }
}

export function useComments(postId: string) {
  const [comments, setComments] = useState<Comment[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchComments(postId).then(({ data }) => {
      setComments((data ?? []).map(mapComment))
      setLoading(false)
    })

    const channel = supabase
      .channel(`comments:${postId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'comments',
        filter: `post_id=eq.${postId}`,
      }, () => {
        fetchComments(postId).then(({ data }) => {
          setComments((data ?? []).map(mapComment))
        })
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [postId])

  return { comments, loading }
}
