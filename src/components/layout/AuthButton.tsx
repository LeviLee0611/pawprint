'use client'

import { useAuth } from '@/hooks/useAuth'
import { signInWithGoogle, signOutUser } from '@/lib/supabase/auth'
import Link from 'next/link'
import { Avatar } from '@/components/ui/Avatar'
import { Button } from '@/components/ui/Button'

export function AuthButton() {
  const { user, loading } = useAuth()

  if (loading) return <div className="h-8 w-20 bg-gray-100 rounded-lg animate-pulse" />

  if (user) {
    const name = user.user_metadata?.full_name ?? user.email ?? '?'
    const photo = user.user_metadata?.avatar_url ?? null
    return (
      <div className="flex items-center gap-3">
        <Link href={`/profile/${user.id}`}>
          <Avatar src={photo} name={name} size="sm" />
        </Link>
        <Button variant="ghost" size="sm" onClick={signOutUser}>
          로그아웃
        </Button>
      </div>
    )
  }

  return (
    <Button size="sm" onClick={signInWithGoogle}>
      로그인
    </Button>
  )
}
