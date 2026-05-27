'use client'

import Link from 'next/link'
import { Header } from '@/components/layout/Header'
import { PostList } from '@/components/post/PostList'
import { Button } from '@/components/ui/Button'
import { usePosts } from '@/hooks/usePosts'
import { useAuth } from '@/hooks/useAuth'

export default function FeedPage() {
  const { posts, loading, hasMore, loadMore } = usePosts()
  const { user } = useAuth()

  return (
    <>
      <Header />
      <main className="max-w-2xl mx-auto px-4 py-6">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-lg font-bold text-gray-900">커뮤니티</h1>
          {user && (
            <Link href="/posts/create">
              <Button size="sm">글 쓰기</Button>
            </Link>
          )}
        </div>
        <PostList posts={posts} loading={loading} hasMore={hasMore} onLoadMore={loadMore} />
      </main>
    </>
  )
}
