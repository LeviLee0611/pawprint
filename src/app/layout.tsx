import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: '냥발도장 - 집사들의 이야기가 모이는 곳',
  description: '고양이 집사들을 위한 커뮤니티',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko" className="h-full">
      <body className="min-h-full antialiased">{children}</body>
    </html>
  )
}
