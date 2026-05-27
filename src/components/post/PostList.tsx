'use client'

import { PostCard } from './PostCard'
import { Spinner } from '@/components/ui/Spinner'
import type { Post } from '@/types'

interface PostListProps {
  posts: Post[]
  loading: boolean
  hasMore: boolean
  onLoadMore: () => void
}

export function PostList({ posts, loading, hasMore, onLoadMore }: PostListProps) {
  if (!loading && posts.length === 0) {
    return (
      <div className="text-center py-20 text-gray-400">
        <p className="text-4xl mb-3">🐱</p>
        <p className="text-sm">아직 글이 없어요. 첫 번째 글을 작성해보세요!</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      {posts.map((post) => (
        <PostCard key={post.id} post={post} />
      ))}

      {loading && (
        <div className="flex justify-center py-8">
          <Spinner />
        </div>
      )}

      {!loading && hasMore && (
        <button
          onClick={onLoadMore}
          className="w-full py-3 text-sm text-gray-500 hover:text-orange-500 transition-colors"
        >
          더 보기
        </button>
      )}
    </div>
  )
}
