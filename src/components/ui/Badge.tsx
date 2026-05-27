import { CATEGORY_COLORS, CATEGORY_LABELS } from '@/constants'
import type { PostCategory } from '@/types'

interface BadgeProps {
  category: PostCategory
}

export function Badge({ category }: BadgeProps) {
  return (
    <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${CATEGORY_COLORS[category]}`}>
      {CATEGORY_LABELS[category]}
    </span>
  )
}
