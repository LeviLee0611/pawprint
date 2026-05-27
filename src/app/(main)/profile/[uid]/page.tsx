'use client'

import { useState, useEffect } from 'react'
import { useParams } from 'next/navigation'
import { fetchProfile, fetchUserPosts } from '@/lib/supabase/queries'
import { Avatar } from '@/components/ui/Avatar'
import { Card } from '@/components/ui/Card'
import { PostCard } from '@/components/post/PostCard'
import { Spinner } from '@/components/ui/Spinner'
import { mapPost } from '@/hooks/usePosts'
import type { Profile, Post } from '@/types'

export default function ProfilePage() {
  const { uid } = useParams<{ uid: string }>()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [posts, setPosts] = useState<Post[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([fetchProfile(uid), fetchUserPosts(uid)]).then(([{ data: p }, { data: ps }]) => {
      if (p) {
        setProfile({
          id: p.id,
          displayName: p.display_name,
          email: p.email,
          photoUrl: p.photo_url,
          createdAt: p.created_at,
          updatedAt: p.updated_at,
        })
      }
      setPosts((ps ?? []).map((row) => mapPost(row as Record<string, unknown>)))
      setLoading(false)
    })
  }, [uid])

  if (loading) return <div className="flex justify-center py-20"><Spinner /></div>
  if (!profile) return <p className="text-center text-gray-400 py-20">유저를 찾을 수 없어요</p>

  return (
    <div className="flex flex-col gap-6">
      <Card>
        <div className="flex items-center gap-4">
          <Avatar src={profile.photoUrl} name={profile.displayName} size="lg" />
          <div>
            <p className="font-semibold text-gray-900">{profile.displayName}</p>
            <p className="text-sm text-gray-400">게시글 {posts.length}개</p>
          </div>
        </div>
      </Card>
      <div>
        <h2 className="text-sm font-semibold text-gray-700 mb-4">작성한 글</h2>
        {posts.length === 0 ? (
          <p className="text-center text-sm text-gray-400 py-10">아직 작성한 글이 없어요</p>
        ) : (
          <div className="flex flex-col gap-4">
            {posts.map((post) => <PostCard key={post.id} post={post} />)}
          </div>
        )}
      </div>
    </div>
  )
}
