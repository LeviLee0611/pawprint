-- ================================================
-- 신고 5회 누적 시 게시글 자동 숨김
-- ================================================

-- 1. posts.is_hidden 컬럼 추가
alter table public.posts
  add column if not exists is_hidden boolean not null default false;

-- 2. posts SELECT RLS: 기존 "모두 조회" 정책을 숨김 제외 정책으로 교체
--    (RLS 정책은 OR로 결합되므로 기존 using(true) 정책을 반드시 제거해야 함)
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where tablename = 'posts' and schemaname = 'public' and cmd = 'SELECT'
  loop
    execute format('drop policy if exists %I on public.posts', pol.policyname);
  end loop;
end $$;

create policy "공개 게시글 조회"
  on public.posts for select
  using (is_hidden = false);

-- 3. 자동 숨김 트리거 함수
create or replace function public.auto_hide_on_reports()
returns trigger
language plpgsql
security definer
as $$
declare
  cnt int;
begin
  select count(*) into cnt
  from public.reports
  where target_id = new.target_id
    and target_type = new.target_type;

  if cnt >= 5 then
    if new.target_type = 'post' then
      update public.posts set is_hidden = true where id = new.target_id::uuid;
    elsif new.target_type = 'community_post' then
      update public.community_posts set status = 'hidden' where id = new.target_id::uuid;
    end if;
  end if;

  return new;
end;
$$;

-- 4. 트리거 등록
drop trigger if exists trigger_auto_hide_on_reports on public.reports;
create trigger trigger_auto_hide_on_reports
  after insert on public.reports
  for each row execute function public.auto_hide_on_reports();
