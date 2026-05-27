import type { PostCategory } from '@/types'

export const CATEGORY_LABELS: Record<PostCategory, string> = {
  question: '질문',
  concern: '고민',
  cute: '귀여움',
  tip: '팁',
  daily: '일상',
}

export const CATEGORY_COLORS: Record<PostCategory, string> = {
  question: 'bg-blue-100 text-blue-700',
  concern: 'bg-orange-100 text-orange-700',
  cute: 'bg-pink-100 text-pink-700',
  tip: 'bg-green-100 text-green-700',
  daily: 'bg-gray-100 text-gray-600',
}

export const POSTS_PER_PAGE = 20
