-- records.pet_id nullable 허용 — 공통 기록(특정 펫 없음) 지원
alter table public.records
  alter column pet_id drop not null;
