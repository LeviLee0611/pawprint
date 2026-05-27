'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/Button'

interface CommentFormProps {
  onSubmit: (content: string) => Promise<void>
}

export function CommentForm({ onSubmit }: CommentFormProps) {
  const [content, setContent] = useState('')
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!content.trim()) return
    setSubmitting(true)
    try {
      await onSubmit(content.trim())
      setContent('')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <input
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="댓글을 입력하세요"
        className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
      />
      <Button type="submit" loading={submitting} disabled={!content.trim()}>
        등록
      </Button>
    </form>
  )
}
