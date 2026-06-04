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

-- ================================================
-- DB 구조 점검 및 최적화 (2026-06-01)
-- ================================================

-- 1. 인덱스 추가 ─ 자주 쓰는 컬럼에 인덱스 없으면 full scan 발생
create index if not exists idx_pets_owner_id
  on public.pets(owner_id);

create index if not exists idx_records_pet_date
  on public.records(pet_id, date);

create index if not exists idx_records_owner_id
  on public.records(owner_id);

create index if not exists idx_posts_owner_id
  on public.posts(owner_id);

create index if not exists idx_posts_created_at
  on public.posts(created_at desc);

create index if not exists idx_comments_post_id
  on public.comments(post_id);

create index if not exists idx_likes_owner_id
  on public.likes(owner_id);

create index if not exists idx_likes_post_id
  on public.likes(post_id);


-- 2. likes_count / comments_count 음수 방지
--    트리거가 count = 0 일 때도 -1 할 수 있어서 방어 제약 추가
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'posts_likes_count_nn') then
    alter table public.posts add constraint posts_likes_count_nn check (likes_count >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'posts_comments_count_nn') then
    alter table public.posts add constraint posts_comments_count_nn check (comments_count >= 0);
  end if;
end $$;

-- 트리거도 보정: 0 이하로 내려가지 않도록
create or replace function update_likes_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create or replace function update_comments_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;


-- 3. fcm_token 보안 강화 ─ profiles의 fcm_token을 별도 테이블로 분리
--    현재 "모두 조회 가능" 정책으로 fcm_token이 타 유저에게 노출됨
create table if not exists public.fcm_tokens (
  owner_id uuid references public.profiles(id) on delete cascade primary key,
  token text not null,
  updated_at timestamptz default now()
);

alter table public.fcm_tokens enable row level security;

drop policy if exists "본인 fcm_token만 관리" on public.fcm_tokens;
create policy "본인 fcm_token만 관리" on public.fcm_tokens
  for all using (auth.uid() = owner_id);

-- Edge Function(서버)이 모든 토큰 읽을 수 있도록
-- (서비스 롤 키를 쓰는 Edge Function은 RLS 우회하므로 별도 정책 불필요)

-- 기존 profiles.fcm_token 데이터 이전
insert into public.fcm_tokens (owner_id, token)
  select id, fcm_token from public.profiles
  where fcm_token is not null
on conflict (owner_id) do update set token = excluded.token;

-- profiles에서 fcm_token 컬럼 제거 (데이터 이전 후)
alter table public.profiles drop column if exists fcm_token;


-- 4. fcm_tokens 멀티 디바이스 지원 (2026-06-04)
--    기존: owner_id PK → 유저당 토큰 1개 (기기 교체/멀티 기기 시 토큰 유실)
--    변경: id UUID PK + token UNIQUE → 기기별 독립 토큰 관리
--    로그아웃 시 해당 기기 토큰만 삭제, 다른 기기 알림 영향 없음
alter table public.fcm_tokens drop constraint if exists fcm_tokens_pkey;
alter table public.fcm_tokens add column if not exists id uuid default gen_random_uuid();
alter table public.fcm_tokens add primary key (id);
alter table public.fcm_tokens add constraint if not exists fcm_tokens_token_unique unique (token);
