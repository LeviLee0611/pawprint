'use client'

import { Avatar } from '@/components/ui/Avatar'
import { Spinner } from '@/components/ui/Spinner'
import type { Comment } from '@/types'
import { formatRelativeTime } from '@/lib/utils'

interface CommentListProps {
  comments: Comment[]
  loading: boolean
  currentUserId?: string
  onDelete: (commentId: string) => void
}

export function CommentList({ comments, loading, currentUserId, onDelete }: CommentListProps) {
  if (loading) {
    return (
      <div className="flex justify-center py-6">
        <Spinner />
      </div>
    )
  }

  if (comments.length === 0) {
    return <p className="text-center text-sm text-gray-400 py-6">아직 댓글이 없어요</p>
  }

  return (
    <ul className="flex flex-col gap-4">
      {comments.map((comment) => (
        <li key={comment.id} className="flex gap-3">
          <Avatar src={comment.authorPhotoUrl} name={comment.authorName} size="sm" />
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-sm font-medium text-gray-800">{comment.authorName}</span>
              <span className="text-xs text-gray-400">{formatRelativeTime(comment.createdAt)}</span>
              {currentUserId === comment.authorId && (
                <button
                  onClick={() => onDelete(comment.id)}
                  className="ml-auto text-xs text-gray-400 hover:text-red-400 transition-colors"
                >
                  삭제
                </button>
              )}
            </div>
            <p className="text-sm text-gray-700 leading-relaxed">{comment.content}</p>
          </div>
        </li>
      ))}
    </ul>
  )
}
