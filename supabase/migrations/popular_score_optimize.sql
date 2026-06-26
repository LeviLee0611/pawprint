-- popular_score 계산 범위를 최근 7일로 제한
-- 7일 넘은 게시글은 점수가 수렴하므로 매시간 재계산 불필요
-- 적용: Supabase SQL Editor에서 실행

CREATE OR REPLACE FUNCTION public.update_popular_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- 7일 이내: 점수 재계산
  UPDATE public.posts
  SET popular_score = (
    (likes_count * 2.0 + comments_count * 3.0 + saves_count * 5.0)
    / POWER(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600.0 + 2.0, 1.5)
  )
  WHERE is_hidden = false
    AND created_at > NOW() - INTERVAL '7 days';
  -- 7일 초과 공개 글: 점수 0으로 리셋 (인기 탭 상단 고정 방지)
  UPDATE public.posts
  SET popular_score = 0
  WHERE is_hidden = false
    AND created_at <= NOW() - INTERVAL '7 days';
  -- 숨김 게시글: 점수 0
  UPDATE public.posts SET popular_score = 0 WHERE is_hidden = true;
END;
$function$;
