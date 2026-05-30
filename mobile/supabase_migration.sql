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
