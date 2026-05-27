'use client'

import Link from 'next/link'
import Image from 'next/image'
import { Card } from '@/components/ui/Card'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import type { Post } from '@/types'
import { formatRelativeTime } from '@/lib/utils'

interface PostCardProps {
  post: Post
}

export function PostCard({ post }: PostCardProps) {
  return (
    <Link href={`/posts/${post.id}`}>
      <Card className="hover:shadow-md transition-shadow cursor-pointer">
        <div className="flex items-center gap-2 mb-3">
          <Avatar src={post.authorPhotoUrl} name={post.authorName} size="sm" />
          <span className="text-sm font-medium text-gray-800">{post.authorName}</span>
          <span className="text-xs text-gray-400 ml-auto">{formatRelativeTime(post.createdAt)}</span>
        </div>

        <div className="mb-3">
          <Badge category={post.category} />
        </div>

        <p className="text-gray-700 text-sm leading-relaxed line-clamp-3 mb-3">{post.content}</p>

        {post.imageUrls.length > 0 && (
          <div className="relative h-48 rounded-xl overflow-hidden mb-3">
            <Image src={post.imageUrls[0]} alt="post image" fill className="object-cover" />
          </div>
        )}

        <div className="flex items-center gap-4 text-xs text-gray-400">
          <span>❤️ {post.likeCount}</span>
          <span>💬 {post.commentCount}</span>
        </div>
      </Card>
    </Link>
  )
}
