-- ============================================================
-- 포포와 토토 — Supabase 마이그레이션 전체 기록
-- 이 파일은 실제 DB에 적용된 SQL을 문서화합니다.
-- Supabase SQL Editor에서 순서대로 실행하세요.
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- [1] notifications 테이블 (알림 — DB 트리거 자동 생성)
-- ──────────────────────────────────────────────────────────

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_notifications_recipient ON public.notifications(recipient_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_select_own" ON public.notifications FOR SELECT USING (auth.uid() = recipient_id);
CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- 좋아요 트리거
CREATE OR REPLACE FUNCTION public.notify_on_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE post_owner UUID;
BEGIN
  SELECT owner_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
  IF post_owner IS NOT NULL AND post_owner != NEW.owner_id THEN
    INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
    VALUES (post_owner, NEW.owner_id, 'like', NEW.post_id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_like AFTER INSERT ON public.likes FOR EACH ROW EXECUTE FUNCTION public.notify_on_like();

-- 좋아요 취소 시 알림 삭제
CREATE OR REPLACE FUNCTION public.delete_notify_on_unlike()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.notifications WHERE actor_id = OLD.owner_id AND type = 'like' AND post_id = OLD.post_id;
  RETURN OLD;
END;
$$;
CREATE TRIGGER trg_delete_notify_unlike AFTER DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.delete_notify_on_unlike();

-- 댓글 트리거
CREATE OR REPLACE FUNCTION public.notify_on_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE post_owner UUID;
BEGIN
  SELECT owner_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
  IF post_owner IS NOT NULL AND post_owner != NEW.owner_id THEN
    INSERT INTO public.notifications (recipient_id, actor_id, type, post_id, comment_id)
    VALUES (post_owner, NEW.owner_id, 'comment', NEW.post_id, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_comment AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.notify_on_comment();

-- 팔로우 트리거
CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.notifications (recipient_id, actor_id, type)
  VALUES (NEW.following_id, NEW.follower_id, 'follow');
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_follow AFTER INSERT ON public.follows FOR EACH ROW EXECUTE FUNCTION public.notify_on_follow();

-- 언팔로우 시 알림 삭제
CREATE OR REPLACE FUNCTION public.delete_notify_on_unfollow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.notifications WHERE actor_id = OLD.follower_id AND recipient_id = OLD.following_id AND type = 'follow';
  RETURN OLD;
END;
$$;
CREATE TRIGGER trg_delete_notify_unfollow AFTER DELETE ON public.follows FOR EACH ROW EXECUTE FUNCTION public.delete_notify_on_unfollow();


-- ──────────────────────────────────────────────────────────
-- [2] app_config 테이블 (강제 업데이트 / 점검 모드)
-- ──────────────────────────────────────────────────────────
-- 아래 두 블록을 나눠서 실행하세요.

-- 블록 1:
CREATE TABLE IF NOT EXISTS public.app_config (
  id INT PRIMARY KEY,
  min_version TEXT NOT NULL DEFAULT '1.0.0',
  store_url_android TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.pawprint.mobile',
  store_url_ios TEXT DEFAULT '',
  maintenance_mode BOOLEAN DEFAULT FALSE,
  maintenance_message TEXT DEFAULT '점검 중이에요. 잠시 후 다시 시도해주세요.'
);

INSERT INTO public.app_config (id, min_version)
VALUES (1, '1.0.0')
ON CONFLICT (id) DO NOTHING;

-- 블록 2 (별도 실행):
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_config_public_read" ON public.app_config FOR SELECT USING (true);


-- ──────────────────────────────────────────────────────────
-- 강제 업데이트 사용법
-- min_version을 올리면 구버전 사용자에게 업데이트 다이얼로그 표시
-- UPDATE public.app_config SET min_version = '1.1.0' WHERE id = 1;
--
-- 점검 모드 활성화
-- UPDATE public.app_config SET maintenance_mode = true, maintenance_message = '점검 중입니다.' WHERE id = 1;
-- ──────────────────────────────────────────────────────────


-- ──────────────────────────────────────────────────────────
-- [3] pets.is_public 컬럼
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.pets ADD COLUMN is_public BOOLEAN DEFAULT TRUE NOT NULL;


-- ──────────────────────────────────────────────────────────
-- [4] record_type enum에 bath 추가
-- ──────────────────────────────────────────────────────────
ALTER TYPE record_type ADD VALUE IF NOT EXISTS 'bath';


-- ──────────────────────────────────────────────────────────
-- [6] notification_settings 테이블 (알림 수신 설정 per 유저)
-- ──────────────────────────────────────────────────────────
CREATE TABLE public.notification_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  like_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  comment_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  follow_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  new_post_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notification_settings_own" ON public.notification_settings
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────
-- [7] reports 테이블 status / handled_at 컬럼 추가
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','resolved','dismissed')),
  ADD COLUMN IF NOT EXISTS handled_at TIMESTAMPTZ;


-- ──────────────────────────────────────────────────────────
-- [8] send-notification Edge Function 웹훅 설정 방법
-- ──────────────────────────────────────────────────────────
-- Supabase 대시보드 → Database → Webhooks → Create Webhook
--
-- 웹훅 1: 좋아요/댓글/팔로우 알림
--   Name: notify_on_notification_insert
--   Table: public.notifications
--   Events: INSERT
--   URL: https://<project-ref>.supabase.co/functions/v1/send-notification
--   HTTP Headers: Authorization: Bearer <service_role_key>
--
-- 웹훅 2 (새 게시글 알림)는 Flutter 앱에서 게시글 등록 후
-- post_service.dart의 addPost()에서 직접 Edge Function 호출
-- (아래 Flutter 코드 참고)
-- ──────────────────────────────────────────────────────────


-- ──────────────────────────────────────────────────────────
-- [5] blocks 테이블 + block_user RPC
-- ──────────────────────────────────────────────────────────
CREATE TABLE public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blocks_select_own" ON public.blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "blocks_insert_own" ON public.blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "blocks_delete_own" ON public.blocks FOR DELETE USING (auth.uid() = blocker_id);

-- 차단 시 팔로우 관계 정리 함수 (SECURITY DEFINER로 RLS 우회)
CREATE OR REPLACE FUNCTION public.block_user(blocked_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE blocker UUID := auth.uid();
BEGIN
  INSERT INTO public.blocks (blocker_id, blocked_id)
  VALUES (blocker, blocked_user_id)
  ON CONFLICT DO NOTHING;
  DELETE FROM public.follows WHERE follower_id = blocker AND following_id = blocked_user_id;
  DELETE FROM public.follows WHERE follower_id = blocked_user_id AND following_id = blocker;
END;
$$;
-- ──────────────────────────────────────────────────────────
