'use client'

import { useState, useRef } from 'react'
import Image from 'next/image'
import { Button } from '@/components/ui/Button'
import { CATEGORY_LABELS } from '@/constants'
import type { PostCategory } from '@/types'

interface PostFormProps {
  onSubmit: (data: { category: PostCategory; content: string; imageFile: File | null }) => Promise<void>
}

const categories = Object.entries(CATEGORY_LABELS) as [PostCategory, string][]

export function PostForm({ onSubmit }: PostFormProps) {
  const [category, setCategory] = useState<PostCategory>('daily')
  const [content, setContent] = useState('')
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  function handleImageChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
  }

  function removeImage() {
    setImageFile(null)
    setImagePreview(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!content.trim()) return
    setSubmitting(true)
    try {
      await onSubmit({ category, content: content.trim(), imageFile })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">카테고리</label>
        <div className="flex flex-wrap gap-2">
          {categories.map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setCategory(value)}
              className={`px-3 py-1.5 rounded-full text-sm transition-colors ${
                category === value
                  ? 'bg-orange-500 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">내용</label>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="고양이 이야기를 들려주세요 🐱"
          rows={6}
          className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-orange-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">사진 (선택)</label>
        {imagePreview ? (
          <div className="relative">
            <div className="relative h-48 rounded-xl overflow-hidden">
              <Image src={imagePreview} alt="preview" fill className="object-cover" />
            </div>
            <button
              type="button"
              onClick={removeImage}
              className="absolute top-2 right-2 bg-black/50 text-white rounded-full w-7 h-7 flex items-center justify-center text-sm hover:bg-black/70"
            >
              ✕
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="w-full h-32 border-2 border-dashed border-gray-200 rounded-xl flex flex-col items-center justify-center gap-2 text-gray-400 hover:border-orange-300 hover:text-orange-400 transition-colors"
          >
            <span className="text-2xl">📷</span>
            <span className="text-sm">사진 추가</span>
          </button>
        )}
        <input ref={fileInputRef} type="file" accept="image/*" onChange={handleImageChange} className="hidden" />
      </div>

      <Button type="submit" loading={submitting} disabled={!content.trim()} size="lg" className="w-full">
        게시하기
      </Button>
    </form>
  )
}
