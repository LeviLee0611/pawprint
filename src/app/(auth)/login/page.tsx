'use client'

import { Button } from '@/components/ui/Button'
import { signInWithGoogle } from '@/lib/supabase/auth'

export default function LoginPage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-[#FAFAF8] px-4">
      <div className="w-full max-w-sm text-center">
        <p className="text-6xl mb-6">🐾</p>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">냥발도장</h1>
        <p className="text-gray-500 text-sm mb-10">집사들의 이야기가 모이는 곳</p>
        <Button onClick={signInWithGoogle} size="lg" className="w-full">
          Google로 시작하기
        </Button>
      </div>
    </div>
  )
}
