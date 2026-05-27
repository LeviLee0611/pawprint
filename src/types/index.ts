export interface Profile {
  id: string
  displayName: string
  email: string
  photoUrl?: string | null
  createdAt: string
  updatedAt: string
}

export type PostCategory = 'question' | 'concern' | 'cute' | 'tip' | 'daily'

export interface Post {
  id: string
  authorId: string
  authorName: string
  authorPhotoUrl?: string | null
  category: PostCategory
  content: string
  imageUrls: string[]
  likeCount: number
  likeUserIds: string[]
  commentCount: number
  createdAt: string
  updatedAt: string
}

export interface Comment {
  id: string
  postId: string
  authorId: string
  authorName: string
  authorPhotoUrl?: string | null
  content: string
  createdAt: string
  updatedAt: string
}
