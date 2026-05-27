import { supabase } from './client'
import type { PostCategory } from '@/types'
import { POSTS_PER_PAGE } from '@/constants'

export async function fetchPosts(from = 0) {
  return supabase
    .from('posts')
    .select(`
      id, author_id, category, content, image_urls,
      like_count, comment_count, created_at, updated_at,
      profiles ( display_name, photo_url ),
      post_likes ( user_id )
    `)
    .order('created_at', { ascending: false })
    .range(from, from + POSTS_PER_PAGE - 1)
}

export async function fetchPost(id: string) {
  return supabase
    .from('posts')
    .select(`
      id, author_id, category, content, image_urls,
      like_count, comment_count, created_at, updated_at,
      profiles ( display_name, photo_url ),
      post_likes ( user_id )
    `)
    .eq('id', id)
    .single()
}

export async function createPost(data: {
  authorId: string
  category: PostCategory
  content: string
  imageUrls: string[]
}) {
  return supabase.from('posts').insert({
    author_id: data.authorId,
    category: data.category,
    content: data.content,
    image_urls: data.imageUrls,
  }).select().single()
}

export async function fetchComments(postId: string) {
  return supabase
    .from('comments')
    .select(`
      id, post_id, author_id, content, created_at, updated_at,
      profiles ( display_name, photo_url )
    `)
    .eq('post_id', postId)
    .order('created_at', { ascending: true })
}

export async function createComment(data: {
  postId: string
  authorId: string
  content: string
}) {
  return supabase.from('comments').insert({
    post_id: data.postId,
    author_id: data.authorId,
    content: data.content,
  })
}

export async function deleteComment(commentId: string) {
  return supabase.from('comments').delete().eq('id', commentId)
}

export async function toggleLike(postId: string, userId: string, liked: boolean) {
  if (liked) {
    return supabase.from('post_likes').delete()
      .eq('post_id', postId).eq('user_id', userId)
  }
  return supabase.from('post_likes').insert({ post_id: postId, user_id: userId })
}

export async function fetchProfile(uid: string) {
  return supabase.from('profiles').select('*').eq('id', uid).single()
}

export async function fetchUserPosts(uid: string) {
  return supabase
    .from('posts')
    .select(`
      id, author_id, category, content, image_urls,
      like_count, comment_count, created_at, updated_at,
      profiles ( display_name, photo_url ),
      post_likes ( user_id )
    `)
    .eq('author_id', uid)
    .order('created_at', { ascending: false })
}

export async function upsertProfile(data: {
  id: string
  displayName: string
  email: string
  photoUrl?: string | null
}) {
  return supabase.from('profiles').upsert({
    id: data.id,
    display_name: data.displayName,
    email: data.email,
    photo_url: data.photoUrl ?? null,
    updated_at: new Date().toISOString(),
  })
}

export async function uploadPostImage(file: File, postId: string) {
  const ext = file.name.split('.').pop()
  const path = `posts/${postId}/${Date.now()}.${ext}`
  const { error } = await supabase.storage.from('post-images').upload(path, file)
  if (error) throw error
  const { data } = supabase.storage.from('post-images').getPublicUrl(path)
  return data.publicUrl
}
