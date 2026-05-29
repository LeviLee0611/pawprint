-- ================================================
-- 냥발도장 Supabase 초기 설정 SQL
-- Supabase SQL Editor에서 전체 실행
-- ================================================

-- 1. profiles (유저 프로필)
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "본인만 수정" on public.profiles
  for all using (auth.uid() = id);

create policy "모두 조회 가능" on public.profiles
  for select using (true);

-- 유저 가입 시 자동으로 profiles 생성
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. pets (반려동물 정보)
create table public.pets (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references public.profiles on delete cascade not null,
  name text not null,
  type text not null default 'cat',  -- 'cat' | 'dog'
  gender text,                        -- 'male' | 'female' | 'neutered'
  breed text,
  birth_date date,
  photo_url text,
  created_at timestamptz default now()
);

alter table public.pets enable row level security;

-- 본인 펫만 조회/수정/삭제 (개인정보 보호)
create policy "본인 펫만 관리" on public.pets
  for all using (auth.uid() = owner_id);


-- 3. records (캘린더 일별 기록)
create type record_type as enum ('meal', 'weight', 'health', 'grooming', 'play', 'note');

create table public.records (
  id uuid default gen_random_uuid() primary key,
  pet_id uuid references public.pets on delete cascade not null,
  owner_id uuid references public.profiles on delete cascade not null,
  date date not null,
  type record_type not null,
  notes text,
  value numeric,
  created_at timestamptz default now()
);

alter table public.records enable row level security;

create policy "본인 기록만 관리" on public.records
  for all using (auth.uid() = owner_id);


-- 4. posts (피드 게시글)
create table public.posts (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references public.profiles on delete cascade not null,
  content text not null,
  image_url text,
  likes_count integer default 0,
  comments_count integer default 0,
  created_at timestamptz default now()
);

alter table public.posts enable row level security;

create policy "본인 글만 수정/삭제" on public.posts
  for all using (auth.uid() = owner_id);

create policy "모두 조회 가능" on public.posts
  for select using (true);


-- 5. comments (댓글)
create table public.comments (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts on delete cascade not null,
  owner_id uuid references public.profiles on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

alter table public.comments enable row level security;

create policy "본인 댓글만 수정/삭제" on public.comments
  for all using (auth.uid() = owner_id);

create policy "모두 조회 가능" on public.comments
  for select using (true);


-- 6. likes (좋아요)
create table public.likes (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts on delete cascade not null,
  owner_id uuid references public.profiles on delete cascade not null,
  created_at timestamptz default now(),
  unique (post_id, owner_id)
);

alter table public.likes enable row level security;

create policy "본인 좋아요만 관리" on public.likes
  for all using (auth.uid() = owner_id);

create policy "모두 조회 가능" on public.likes
  for select using (true);


-- 7. likes_count 자동 업데이트 트리거
create or replace function update_likes_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set likes_count = likes_count - 1 where id = old.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger on_like_change
  after insert or delete on public.likes
  for each row execute procedure update_likes_count();


-- 8. comments_count 자동 업데이트 트리거
create or replace function update_comments_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set comments_count = comments_count - 1 where id = old.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger on_comment_change
  after insert or delete on public.comments
  for each row execute procedure update_comments_count();


-- 9. Storage 버킷 (pet-photos, post-images)
insert into storage.buckets (id, name, public) values ('pet-photos', 'pet-photos', true);
insert into storage.buckets (id, name, public) values ('post-images', 'post-images', true);

create policy "누구나 이미지 조회" on storage.objects
  for select using (bucket_id in ('pet-photos', 'post-images'));

create policy "로그인 유저 업로드" on storage.objects
  for insert with check (auth.role() = 'authenticated' and bucket_id in ('pet-photos', 'post-images'));

create policy "본인 이미지만 삭제" on storage.objects
  for delete using (auth.uid()::text = (storage.foldername(name))[1] and bucket_id in ('pet-photos', 'post-images'));
