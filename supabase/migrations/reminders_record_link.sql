-- 알림을 특정 기록과 연결하기 위한 record_id 컬럼 추가
-- 같은 펫의 다른 예방접종 알림이 한 기록 상세에 모두 표시되는 문제 해결
ALTER TABLE public.reminders
  ADD COLUMN IF NOT EXISTS record_id uuid REFERENCES public.records(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS reminders_record_id_idx ON public.reminders(record_id);

-- remind_at을 timestamptz로 변경 (date → timestamptz, 이미 실행했다면 무시)
-- ALTER TABLE public.reminders ALTER COLUMN remind_at TYPE timestamptz USING remind_at::date::timestamptz;

-- 기존 알림에 record_id 없어도 정상 동작 (nullable)
