-- ================================================
-- community_posts 전체 테이블
-- ================================================
create table if not exists public.community_posts (
  id            uuid default gen_random_uuid() primary key,
  owner_id      uuid references public.profiles(id) on delete cascade not null,
  category      text not null check (category in ('lost', 'found', 'rehome', 'looking')),
  title         text not null,
  content       text not null default '',
  image_urls    text[] not null default '{}',
  pet_name      text,
  pet_type      text check (pet_type in ('cat', 'dog')),
  location      text,
  contact       text,
  status        text not null default 'open' check (status in ('open', 'resolved', 'hidden')),
  address       text,
  latitude      double precision,
  longitude     double precision,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table public.community_posts enable row level security;

drop policy if exists "커뮤니티 게시글 조회" on public.community_posts;
create policy "커뮤니티 게시글 조회" on public.community_posts
  for select using (status != 'hidden');

drop policy if exists "커뮤니티 게시글 작성" on public.community_posts;
create policy "커뮤니티 게시글 작성" on public.community_posts
  for insert with check (auth.uid() = owner_id);

drop policy if exists "커뮤니티 게시글 수정" on public.community_posts;
create policy "커뮤니티 게시글 수정" on public.community_posts
  for update using (auth.uid() = owner_id);

drop policy if exists "커뮤니티 게시글 삭제" on public.community_posts;
create policy "커뮤니티 게시글 삭제" on public.community_posts
  for delete using (auth.uid() = owner_id);

create index if not exists idx_community_posts_owner on public.community_posts(owner_id);
create index if not exists idx_community_posts_category on public.community_posts(category);
create index if not exists idx_community_posts_created on public.community_posts(created_at desc);
create index if not exists idx_community_posts_status on public.community_posts(status);

-- ================================================
-- sighting_reports 전체 테이블
-- ================================================
create table if not exists public.sighting_reports (
  id          uuid default gen_random_uuid() primary key,
  post_id     uuid references public.community_posts(id) on delete cascade not null,
  reporter_id uuid references public.profiles(id) on delete cascade not null,
  address     text,
  latitude    double precision,
  longitude   double precision,
  note        text,
  created_at  timestamptz default now(),
  unique (post_id, reporter_id)
);

alter table public.sighting_reports enable row level security;

drop policy if exists "목격 신고 조회" on public.sighting_reports;
create policy "목격 신고 조회" on public.sighting_reports
  for select using (true);

drop policy if exists "목격 신고 작성" on public.sighting_reports;
create policy "목격 신고 작성" on public.sighting_reports
  for insert with check (auth.uid() = reporter_id);

create index if not exists idx_sighting_reports_post on public.sighting_reports(post_id);

-- ================================================
-- posts.image_urls 다중 이미지 컬럼
-- ================================================
alter table public.posts
  add column if not exists image_urls text[] not null default '{}';

-- ================================================
-- reports.target_type 에 community_post 추가
-- ================================================
alter table public.reports
  drop constraint if exists reports_target_type_check;

alter table public.reports
  add constraint reports_target_type_check
  check (target_type in ('post', 'comment', 'community_post'));
