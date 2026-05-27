'use client'

import Link from 'next/link'
import { AuthButton } from './AuthButton'

export function Header() {
  return (
    <header className="sticky top-0 z-50 bg-white border-b border-gray-100">
      <div className="max-w-2xl mx-auto px-4 h-14 flex items-center justify-between">
        <Link href="/" className="text-lg font-bold text-orange-500">
          🐾 냥발도장
        </Link>
        <AuthButton />
      </div>
    </header>
  )
}
