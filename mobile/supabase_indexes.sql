-- ================================================
-- 냥발도장 인덱스 + 보완 설정
-- supabase_setup.sql 실행 후 추가로 실행
-- ================================================

-- 1. updated_at 컬럼 추가
alter table public.profiles add column updated_at timestamptz default now();
alter table public.pets add column updated_at timestamptz default now();
alter table public.posts add column updated_at timestamptz default now();

-- updated_at 자동 갱신 함수
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at before update on public.profiles
  for each row execute procedure update_updated_at();

create trigger pets_updated_at before update on public.pets
  for each row execute procedure update_updated_at();

create trigger posts_updated_at before update on public.posts
  for each row execute procedure update_updated_at();


-- 2. 인덱스 (자주 쓰는 쿼리 기준)
create index on public.pets (owner_id);
create index on public.records (pet_id, date);
create index on public.records (owner_id);
create index on public.posts (owner_id);
create index on public.posts (created_at desc);
create index on public.comments (post_id);
create index on public.likes (post_id);


-- 3. Storage 정책 보완 (업로드 시 본인 폴더에만 저장)
drop policy if exists "로그인 유저 업로드" on storage.objects;

create policy "본인 폴더에만 업로드" on storage.objects
  for insert with check (
    auth.role() = 'authenticated'
    and bucket_id in ('pet-photos', 'post-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "본인 파일만 수정" on storage.objects
  for update using (
    auth.uid()::text = (storage.foldername(name))[1]
    and bucket_id in ('pet-photos', 'post-images')
  );
