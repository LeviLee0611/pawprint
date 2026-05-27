'use client'

import { useState, useEffect } from 'react'
import { useParams } from 'next/navigation'
import Image from 'next/image'
import { useAuth } from '@/hooks/useAuth'
import { useComments } from '@/hooks/useComments'
import { fetchPost, createComment, deleteComment, toggleLike, upsertProfile } from '@/lib/supabase/queries'
import { supabase } from '@/lib/supabase/client'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { CommentList } from '@/components/post/CommentList'
import { CommentForm } from '@/components/post/CommentForm'
import { Spinner } from '@/components/ui/Spinner'
import { mapPost } from '@/hooks/usePosts'
import type { Post } from '@/types'
import { formatRelativeTime } from '@/lib/utils'

export default function PostDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const { comments, loading: commentsLoading } = useComments(id)
  const [post, setPost] = useState<Post | null>(null)
  const [postLoading, setPostLoading] = useState(true)

  useEffect(() => {
    fetchPost(id).then(({ data }) => {
      if (data) setPost(mapPost(data as Record<string, unknown>))
      setPostLoading(false)
    })
  }, [id])

  async function handleLike() {
    if (!user || !post) return
    const liked = post.likeUserIds.includes(user.id)
    setPost((prev) =>
      prev ? {
        ...prev,
        likeCount: liked ? prev.likeCount - 1 : prev.likeCount + 1,
        likeUserIds: liked
          ? prev.likeUserIds.filter((uid) => uid !== user.id)
          : [...prev.likeUserIds, user.id],
      } : prev
    )
    await toggleLike(id, user.id, liked)
    await supabase.from('posts').update({
      like_count: liked ? post.likeCount - 1 : post.likeCount + 1,
    }).eq('id', id)
  }

  async function handleAddComment(content: string) {
    if (!user) return
    await upsertProfile({
      id: user.id,
      displayName: user.user_metadata?.full_name ?? user.email ?? '익명',
      email: user.email ?? '',
      photoUrl: user.user_metadata?.avatar_url ?? null,
    })
    await createComment({ postId: id, authorId: user.id, content })
    await supabase.from('posts').update({ comment_count: (post?.commentCount ?? 0) + 1 }).eq('id', id)
    setPost((prev) => prev ? { ...prev, commentCount: prev.commentCount + 1 } : prev)
  }

  async function handleDeleteComment(commentId: string) {
    await deleteComment(commentId)
    await supabase.from('posts').update({ comment_count: (post?.commentCount ?? 1) - 1 }).eq('id', id)
    setPost((prev) => prev ? { ...prev, commentCount: prev.commentCount - 1 } : prev)
  }

  if (postLoading) return <div className="flex justify-center py-20"><Spinner /></div>
  if (!post) return <p className="text-center text-gray-400 py-20">글을 찾을 수 없어요</p>

  const liked = user ? post.likeUserIds.includes(user.id) : false

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <div className="flex items-center gap-2 mb-4">
          <Avatar src={post.authorPhotoUrl} name={post.authorName} />
          <div>
            <p className="text-sm font-medium text-gray-800">{post.authorName}</p>
            <p className="text-xs text-gray-400">{formatRelativeTime(post.createdAt)}</p>
          </div>
        </div>
        <Badge category={post.category} />
        <p className="mt-3 text-gray-700 leading-relaxed whitespace-pre-wrap">{post.content}</p>
        {post.imageUrls.length > 0 && (
          <div className="relative mt-4 h-64 rounded-xl overflow-hidden">
            <Image src={post.imageUrls[0]} alt="post image" fill className="object-cover" />
          </div>
        )}
        <button
          onClick={handleLike}
          className={`mt-4 flex items-center gap-1.5 text-sm transition-colors ${liked ? 'text-red-500' : 'text-gray-400 hover:text-red-400'}`}
        >
          {liked ? '❤️' : '🤍'} {post.likeCount}
        </button>
      </Card>

      <Card>
        <h2 className="text-sm font-semibold text-gray-700 mb-4">댓글 {post.commentCount}개</h2>
        <CommentList
          comments={comments}
          loading={commentsLoading}
          currentUserId={user?.id}
          onDelete={handleDeleteComment}
        />
        {user ? (
          <div className="mt-4 pt-4 border-t border-gray-100">
            <CommentForm onSubmit={handleAddComment} />
          </div>
        ) : (
          <p className="mt-4 pt-4 border-t border-gray-100 text-center text-sm text-gray-400">
            댓글을 달려면 로그인이 필요해요
          </p>
        )}
      </Card>
    </div>
  )
}
