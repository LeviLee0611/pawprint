-- ================================================
-- 마이그레이션: posts 테이블에 pet_id 컬럼 추가
-- Supabase SQL Editor에서 실행
-- ================================================

alter table public.posts
  add column if not exists pet_id uuid references public.pets(id) on delete set null;

-- pets RLS: 피드에서 다른 유저 펫 이름을 join해서 읽을 수 있도록 조회 허용
drop policy if exists "피드에서 펫 이름 조회 허용" on public.pets;
create policy "피드에서 펫 이름 조회 허용" on public.pets
  for select using (true);

-- ================================================
-- 마이그레이션: 답글(parent_id) 기능
-- ================================================

alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade;

create index if not exists idx_comments_parent_id on public.comments(parent_id);
create index if not exists idx_comments_post_parent on public.comments(post_id, parent_id, created_at);

-- ================================================
-- 마이그레이션: 댓글 RLS — 게시글 작성자도 삭제 가능
-- ================================================

drop policy if exists "본인 댓글만 수정/삭제" on public.comments;

create policy "댓글 삽입" on public.comments
  for insert with check (auth.uid() = owner_id);

create policy "댓글 삭제 권한" on public.comments
  for delete using (
    auth.uid() = owner_id
    or auth.uid() = (select owner_id from public.posts where id = post_id)
  );

-- ================================================
-- 마이그레이션: 신고(reports) 테이블
-- ================================================

create table if not exists public.reports (
  id uuid default gen_random_uuid() primary key,
  reporter_id uuid references auth.users on delete cascade not null,
  target_type text not null check (target_type in ('post', 'comment')),
  target_id uuid not null,
  reason text not null,
  created_at timestamptz default now(),
  unique (reporter_id, target_type, target_id)
);

alter table public.reports enable row level security;

drop policy if exists "신고 삽입" on public.reports;
create policy "신고 삽입" on public.reports
  for insert with check (auth.uid() = reporter_id);

drop policy if exists "본인 신고 조회" on public.reports;
create policy "본인 신고 조회" on public.reports
  for select using (auth.uid() = reporter_id);

-- ================================================
-- 마이그레이션: profiles display_name null 방지
-- ================================================

update public.profiles p
set display_name = coalesce(
  u.raw_user_meta_data->>'full_name',
  u.raw_user_meta_data->>'name',
  split_part(u.email, '@', 1)
)
from auth.users u
where p.id = u.id and (p.display_name is null or p.display_name = '');

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1),
      '사용자'
    ),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;
