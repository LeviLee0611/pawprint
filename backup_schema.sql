-- =====================================================
-- 댕냥스토리 Supabase Schema Backup
-- Date: 2026-06-10
-- Source: database.md + Flutter code analysis
-- Project ID (US): puhharfjbbpqecycapbx
-- =====================================================
--
-- [사용 방법]
-- 1. 아래 STEP 1 쿼리를 현재 US Supabase SQL Editor에서 실행
--    → trigger 함수 본문 + RLS 정책 SQL을 이 파일에 추가
-- 2. 새 서울 프로젝트 SQL Editor에서 이 파일 전체 실행
-- =====================================================

-- =====================================================
-- STEP 1: 현재 US 프로젝트에서 실행해서 결과를 이 파일에 추가
-- =====================================================

-- [트리거 함수 본문 가져오기]
-- SELECT pg_get_functiondef(p.oid) || E'\n'
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
-- ORDER BY p.proname;

-- [RLS 정책 SQL 가져오기]
-- SELECT
--   'ALTER TABLE ' || quote_ident(tablename) || ' ENABLE ROW LEVEL SECURITY;' || E'\n' ||
--   'CREATE POLICY ' || quote_ident(policyname) || ' ON public.' || quote_ident(tablename) ||
--   ' AS ' || permissive ||
--   ' FOR ' || cmd ||
--   CASE WHEN roles IS NOT NULL THEN ' TO ' || array_to_string(roles, ', ') ELSE '' END ||
--   CASE WHEN qual IS NOT NULL THEN E'\n  USING (' || qual || ')' ELSE '' END ||
--   CASE WHEN with_check IS NOT NULL THEN E'\n  WITH CHECK (' || with_check || ')' ELSE '' END || ';'
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;

-- =====================================================
-- EXTENSIONS
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- TABLES
-- =====================================================

-- profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT
);

-- pets
CREATE TABLE IF NOT EXISTS public.pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('cat', 'dog')),
  breed TEXT,
  birth_date DATE,
  gender TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- records
CREATE TABLE IF NOT EXISTS public.records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('health', 'weight', 'note', 'meal', 'grooming', 'play', 'bath', 'photo')),
  value NUMERIC,
  notes TEXT,
  photo_url TEXT,
  date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- posts
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES public.pets(id) ON DELETE SET NULL,
  content TEXT,
  image_url TEXT,
  image_urls TEXT[] DEFAULT '{}',
  likes_count INT NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  comments_count INT NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- comments
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- likes
CREATE TABLE IF NOT EXISTS public.likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, owner_id)
);

-- saves
CREATE TABLE IF NOT EXISTS public.saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_id, post_id)
);

-- follows
CREATE TABLE IF NOT EXISTS public.follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (follower_id, following_id)
);

-- fcm_tokens
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- reports
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'community_post')),
  target_id UUID NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, target_type, target_id)
);

-- notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- notification_settings
CREATE TABLE IF NOT EXISTS public.notification_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  like_setting TEXT NOT NULL DEFAULT 'everyone' CHECK (like_setting IN ('everyone', 'following_only', 'off')),
  comment_setting TEXT NOT NULL DEFAULT 'everyone' CHECK (comment_setting IN ('everyone', 'following_only', 'off')),
  follow_enabled BOOLEAN NOT NULL DEFAULT true,
  new_post_enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- blocks
CREATE TABLE IF NOT EXISTS public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_id)
);

-- community_posts
CREATE TABLE IF NOT EXISTS public.community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('lost', 'found', 'rehome', 'looking', 'tip', 'question')),
  title TEXT NOT NULL,
  content TEXT,
  image_urls TEXT[] NOT NULL DEFAULT '{}',
  pet_name TEXT,
  pet_type TEXT CHECK (pet_type IN ('cat', 'dog')),
  location TEXT,
  contact TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'hidden')),
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- sighting_reports
CREATE TABLE IF NOT EXISTS public.sighting_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, reporter_id)
);

-- chat_rooms
CREATE TABLE IF NOT EXISTS public.chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  helper_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, helper_id)
);

-- chat_messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- reminders
CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  remind_at DATE NOT NULL,
  sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- app_feedback
CREATE TABLE IF NOT EXISTS public.app_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  category TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- birthday_notifications_sent (생일 알림 중복 방지)
CREATE TABLE IF NOT EXISTS public.birthday_notifications_sent (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  sent_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_id, pet_id, sent_date)
);

-- app_config (단일 행, id=1)
CREATE TABLE IF NOT EXISTS public.app_config (
  id INT PRIMARY KEY DEFAULT 1,
  min_version TEXT NOT NULL DEFAULT '1.0.0',
  store_url_android TEXT DEFAULT '',
  store_url_ios TEXT DEFAULT '',
  maintenance_mode BOOLEAN NOT NULL DEFAULT false,
  maintenance_message TEXT DEFAULT '점검 중이에요. 잠시 후 다시 시도해주세요.',
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO public.app_config (id) VALUES (1) ON CONFLICT DO NOTHING;

-- =====================================================
-- INDEXES
-- =====================================================

-- pets
CREATE INDEX IF NOT EXISTS idx_pets_owner_id ON public.pets(owner_id);

-- records
CREATE INDEX IF NOT EXISTS idx_records_pet_date ON public.records(pet_id, date);
CREATE INDEX IF NOT EXISTS idx_records_owner_id ON public.records(owner_id);

-- posts
CREATE INDEX IF NOT EXISTS idx_posts_owner_id ON public.posts(owner_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);

-- comments
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_parent ON public.comments(post_id, parent_id);

-- likes
CREATE INDEX IF NOT EXISTS idx_likes_owner_id ON public.likes(owner_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON public.likes(post_id);

-- saves
CREATE INDEX IF NOT EXISTS saves_owner_id_idx ON public.saves(owner_id);
CREATE INDEX IF NOT EXISTS saves_post_id_idx ON public.saves(post_id);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id, created_at DESC);

-- community_posts
CREATE INDEX IF NOT EXISTS idx_community_posts_owner ON public.community_posts(owner_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_category ON public.community_posts(category);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON public.community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_status ON public.community_posts(status);

-- sighting_reports
CREATE INDEX IF NOT EXISTS idx_sighting_reports_post ON public.sighting_reports(post_id);

-- chat
CREATE INDEX IF NOT EXISTS idx_chat_rooms_author ON public.chat_rooms(author_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_helper ON public.chat_rooms(helper_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages(room_id, created_at);

-- reminders
CREATE INDEX IF NOT EXISTS idx_reminders_owner ON public.reminders(owner_id);
CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON public.reminders(remind_at) WHERE sent = false;

-- =====================================================
-- STORAGE BUCKETS
-- =====================================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('pet-photos', 'pet-photos', true),
  ('post-images', 'post-images', true),
  ('record-photos', 'record-photos', true)
ON CONFLICT DO NOTHING;

-- STORAGE RLS POLICIES
-- pet-photos
DROP POLICY IF EXISTS "pet_photos_select" ON storage.objects;
CREATE POLICY "pet_photos_select" ON storage.objects FOR SELECT TO public USING (bucket_id = 'pet-photos');
DROP POLICY IF EXISTS "pet_photos_insert" ON storage.objects;
CREATE POLICY "pet_photos_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "pet_photos_update" ON storage.objects;
CREATE POLICY "pet_photos_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "pet_photos_delete" ON storage.objects;
CREATE POLICY "pet_photos_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- post-images
DROP POLICY IF EXISTS "post_images_select" ON storage.objects;
CREATE POLICY "post_images_select" ON storage.objects FOR SELECT TO public USING (bucket_id = 'post-images');
DROP POLICY IF EXISTS "post_images_insert" ON storage.objects;
CREATE POLICY "post_images_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "post_images_update" ON storage.objects;
CREATE POLICY "post_images_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "post_images_delete" ON storage.objects;
CREATE POLICY "post_images_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- record-photos
DROP POLICY IF EXISTS "record_photos_select" ON storage.objects;
CREATE POLICY "record_photos_select" ON storage.objects FOR SELECT TO public USING (bucket_id = 'record-photos');
DROP POLICY IF EXISTS "record_photos_insert" ON storage.objects;
CREATE POLICY "record_photos_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'record-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "record_photos_update" ON storage.objects;
CREATE POLICY "record_photos_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'record-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "record_photos_delete" ON storage.objects;
CREATE POLICY "record_photos_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'record-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =====================================================
-- EXTENSIONS (트리거에서 net.http_post 사용)
-- =====================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

-- =====================================================
-- TRIGGER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  begin
    if TG_OP = 'INSERT' then
      update public.posts set likes_count = likes_count + 1 where id = new.post_id;
    elsif TG_OP = 'DELETE' then
      update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
    end if;
    return null;
  end;
$function$;

CREATE OR REPLACE FUNCTION public.update_comments_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  begin
    if TG_OP = 'INSERT' then
      update public.posts set comments_count = comments_count + 1 where id = new.post_id;
    elsif TG_OP = 'DELETE' then
      update public.posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
    end if;
    return null;
  end;
$function$;

CREATE OR REPLACE FUNCTION public.auto_hide_on_reports()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.notify_on_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  DECLARE post_owner UUID;
  BEGIN
    SELECT owner_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
    IF post_owner IS NOT NULL AND post_owner != NEW.owner_id THEN
      INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
      VALUES (post_owner, NEW.owner_id, 'like', NEW.post_id);
    END IF;
    RETURN NEW;
  END;
$function$;

CREATE OR REPLACE FUNCTION public.delete_notify_on_unlike()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  BEGIN
    DELETE FROM public.notifications WHERE actor_id = OLD.owner_id AND type = 'like' AND post_id = OLD.post_id;
    RETURN OLD;
  END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_on_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  DECLARE post_owner UUID;
  BEGIN
    SELECT owner_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
    IF post_owner IS NOT NULL AND post_owner != NEW.owner_id THEN
      INSERT INTO public.notifications (recipient_id, actor_id, type, post_id, comment_id)
      VALUES (post_owner, NEW.owner_id, 'comment', NEW.post_id, NEW.id);
    END IF;
    RETURN NEW;
  END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  BEGIN
    INSERT INTO public.notifications (recipient_id, actor_id, type)
    VALUES (NEW.following_id, NEW.follower_id, 'follow');
    RETURN NEW;
  END;
$function$;

CREATE OR REPLACE FUNCTION public.delete_notify_on_unfollow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  BEGIN
    DELETE FROM public.notifications WHERE actor_id = OLD.follower_id AND recipient_id = OLD.following_id AND type = 'follow';
    RETURN OLD;
  END;
$function$;

CREATE OR REPLACE FUNCTION public.update_chat_room_last_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  begin
    update public.chat_rooms
    set last_message_at = new.created_at
    where id = new.room_id;
    return new;
  end;
$function$;

CREATE OR REPLACE FUNCTION public.set_community_posts_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  begin
    new.updated_at = now();
    return new;
  end;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_birthday_pets(p_month integer, p_day integer)
RETURNS TABLE(id uuid, name text, type text, owner_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
    select id, name, type, owner_id
    from public.pets
    where birth_date is not null
      and extract(month from birth_date) = p_month
      and extract(day from birth_date) = p_day;
$function$;

-- 알림 발송: DB 트리거 → net.http_post → Edge Function (send-notification)
-- ⚠️ 이 파일에는 실제 키를 절대 저장하지 말 것
-- 새 DB 설치 시: SQL Editor에서만 SUPABASE_SERVICE_ROLE_KEY를 실제 값으로 치환해 실행하고 저장 금지
-- (서버 전용 함수 — 클라이언트에 노출되지 않음)
CREATE OR REPLACE FUNCTION public.trigger_send_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM net.http_post(
    url := 'https://wosuipvdblhpgutkxjkn.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer SUPABASE_SERVICE_ROLE_KEY'
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', TG_TABLE_NAME,
      'record', row_to_json(NEW)
    )
  );
  RETURN NEW;
END;
$function$;

-- RPC
CREATE OR REPLACE FUNCTION public.block_user(blocked_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  DECLARE blocker UUID := auth.uid();
  BEGIN
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (blocker, blocked_user_id)
    ON CONFLICT DO NOTHING;
    DELETE FROM public.follows WHERE follower_id = blocker AND following_id = blocked_user_id;
    DELETE FROM public.follows WHERE follower_id = blocked_user_id AND following_id = blocker;
  END;
$function$;

-- =====================================================
-- TRIGGERS
-- =====================================================

DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
CREATE TRIGGER handle_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_likes_count ON public.likes;
CREATE TRIGGER update_likes_count
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();

DROP TRIGGER IF EXISTS update_comments_count ON public.comments;
CREATE TRIGGER update_comments_count
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.update_comments_count();

DROP TRIGGER IF EXISTS trigger_auto_hide_on_reports ON public.reports;
CREATE TRIGGER trigger_auto_hide_on_reports
  AFTER INSERT ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.auto_hide_on_reports();

DROP TRIGGER IF EXISTS trg_notify_like ON public.likes;
CREATE TRIGGER trg_notify_like
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_like();

DROP TRIGGER IF EXISTS trg_delete_notify_unlike ON public.likes;
CREATE TRIGGER trg_delete_notify_unlike
  AFTER DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.delete_notify_on_unlike();

DROP TRIGGER IF EXISTS trg_notify_comment ON public.comments;
CREATE TRIGGER trg_notify_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_comment();

DROP TRIGGER IF EXISTS trg_notify_follow ON public.follows;
CREATE TRIGGER trg_notify_follow
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_follow();

DROP TRIGGER IF EXISTS trg_delete_notify_unfollow ON public.follows;
CREATE TRIGGER trg_delete_notify_unfollow
  AFTER DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.delete_notify_on_unfollow();

DROP TRIGGER IF EXISTS trg_send_notification ON public.notifications;
CREATE TRIGGER trg_send_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.trigger_send_notification();

DROP TRIGGER IF EXISTS trg_send_notification_report ON public.reports;
CREATE TRIGGER trg_send_notification_report
  AFTER INSERT ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.trigger_send_notification();

DROP TRIGGER IF EXISTS trg_chat_messages_last_message ON public.chat_messages;
CREATE TRIGGER trg_chat_messages_last_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.update_chat_room_last_message();

DROP TRIGGER IF EXISTS trg_community_posts_updated_at ON public.community_posts;
CREATE TRIGGER trg_community_posts_updated_at
  BEFORE UPDATE ON public.community_posts
  FOR EACH ROW EXECUTE FUNCTION public.set_community_posts_updated_at();

DROP TRIGGER IF EXISTS set_posts_updated_at ON public.posts;
CREATE TRIGGER set_posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Realtime (채팅 실시간 기능)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END;
$$;

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- app_config
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_config_public_read ON public.app_config;
CREATE POLICY app_config_public_read ON public.app_config AS PERMISSIVE FOR SELECT TO public USING (true);

-- app_feedback
ALTER TABLE public.app_feedback ENABLE ROW LEVEL SECURITY;
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- ⚠️  반드시 교체: 아래 UUID를 새 프로젝트 로그인 후 실제 UUID로 바꿔야 함
--     Supabase Dashboard → Authentication → Users → 본인 계정 ID 확인
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
DROP POLICY IF EXISTS "관리자 조회" ON public.app_feedback;
CREATE POLICY "관리자 조회" ON public.app_feedback AS PERMISSIVE FOR SELECT TO public
  USING ((auth.uid() = '99244f0e-6035-49df-9189-27caf6df9c89'::uuid) OR (auth.uid() = 'b8ea8060-898b-4b2a-a98e-897e90be7d1f'::uuid));
DROP POLICY IF EXISTS "피드백 제출" ON public.app_feedback;
CREATE POLICY "피드백 제출" ON public.app_feedback AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- blocks
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS blocks_delete_own ON public.blocks;
CREATE POLICY blocks_delete_own ON public.blocks AS PERMISSIVE FOR DELETE TO public USING ((auth.uid() = blocker_id));
DROP POLICY IF EXISTS blocks_insert_own ON public.blocks;
CREATE POLICY blocks_insert_own ON public.blocks AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = blocker_id));
DROP POLICY IF EXISTS blocks_select_own ON public.blocks;
CREATE POLICY blocks_select_own ON public.blocks AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = blocker_id));

-- chat_messages
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "채팅 메시지 조회" ON public.chat_messages;
CREATE POLICY "채팅 메시지 조회" ON public.chat_messages AS PERMISSIVE FOR SELECT TO public
  USING ((EXISTS (SELECT 1 FROM chat_rooms r WHERE ((r.id = chat_messages.room_id) AND ((r.author_id = auth.uid()) OR (r.helper_id = auth.uid()))))));
DROP POLICY IF EXISTS "채팅 메시지 전송" ON public.chat_messages;
CREATE POLICY "채팅 메시지 전송" ON public.chat_messages AS PERMISSIVE FOR INSERT TO public
  WITH CHECK (((auth.uid() = sender_id) AND (EXISTS (SELECT 1 FROM chat_rooms r WHERE ((r.id = chat_messages.room_id) AND ((r.author_id = auth.uid()) OR (r.helper_id = auth.uid())))))));

-- chat_rooms
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "채팅방 조회" ON public.chat_rooms;
CREATE POLICY "채팅방 조회" ON public.chat_rooms AS PERMISSIVE FOR SELECT TO public
  USING (((auth.uid() = author_id) OR (auth.uid() = helper_id)));
DROP POLICY IF EXISTS "채팅방 생성" ON public.chat_rooms;
CREATE POLICY "채팅방 생성" ON public.chat_rooms AS PERMISSIVE FOR INSERT TO public
  WITH CHECK (((auth.uid() = helper_id) AND (helper_id <> author_id) AND (EXISTS (SELECT 1 FROM community_posts p WHERE ((p.id = chat_rooms.post_id) AND (p.owner_id = chat_rooms.author_id))))));
DROP POLICY IF EXISTS "participants update" ON public.chat_rooms;
-- UPDATE 정책 제거: last_message_at은 DB trigger가 갱신하므로 클라이언트 UPDATE 불필요

-- comments
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "모두 조회 가능" ON public.comments;
CREATE POLICY "모두 조회 가능" ON public.comments AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "본인 댓글만 삽입" ON public.comments;
CREATE POLICY "본인 댓글만 삽입" ON public.comments AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = owner_id));
DROP POLICY IF EXISTS "댓글 삭제 권한" ON public.comments;
CREATE POLICY "댓글 삭제 권한" ON public.comments AS PERMISSIVE FOR DELETE TO public
  USING (((auth.uid() = owner_id) OR (auth.uid() = (SELECT posts.owner_id FROM posts WHERE (posts.id = comments.post_id)))));

-- community_posts
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "커뮤니티 게시글 조회" ON public.community_posts;
CREATE POLICY "커뮤니티 게시글 조회" ON public.community_posts AS PERMISSIVE FOR SELECT TO public USING ((status <> 'hidden'::text));
DROP POLICY IF EXISTS "커뮤니티 게시글 작성" ON public.community_posts;
CREATE POLICY "커뮤니티 게시글 작성" ON public.community_posts AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = owner_id));
DROP POLICY IF EXISTS "커뮤니티 게시글 수정" ON public.community_posts;
CREATE POLICY "커뮤니티 게시글 수정" ON public.community_posts AS PERMISSIVE FOR UPDATE TO public USING ((auth.uid() = owner_id));
DROP POLICY IF EXISTS "커뮤니티 게시글 삭제" ON public.community_posts;
CREATE POLICY "커뮤니티 게시글 삭제" ON public.community_posts AS PERMISSIVE FOR DELETE TO public USING ((auth.uid() = owner_id));

-- fcm_tokens
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "본인 fcm_token만 관리" ON public.fcm_tokens;
CREATE POLICY "본인 fcm_token만 관리" ON public.fcm_tokens AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- follows
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view follows" ON public.follows;
CREATE POLICY "Anyone can view follows" ON public.follows AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "Users can follow others" ON public.follows;
CREATE POLICY "Users can follow others" ON public.follows AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = follower_id));
DROP POLICY IF EXISTS "Users can unfollow" ON public.follows;
CREATE POLICY "Users can unfollow" ON public.follows AS PERMISSIVE FOR DELETE TO public USING ((auth.uid() = follower_id));

-- likes
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "모두 조회 가능" ON public.likes;
CREATE POLICY "모두 조회 가능" ON public.likes AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "본인 좋아요만 관리" ON public.likes;
CREATE POLICY "본인 좋아요만 관리" ON public.likes AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- notification_settings
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notification_settings_own ON public.notification_settings;
CREATE POLICY notification_settings_own ON public.notification_settings AS PERMISSIVE FOR ALL TO public
  USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

-- notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own ON public.notifications AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = recipient_id));
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own ON public.notifications AS PERMISSIVE FOR UPDATE TO public USING ((auth.uid() = recipient_id));

-- pets
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "모두 조회 가능" ON public.pets;
CREATE POLICY "모두 조회 가능" ON public.pets AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "본인 펫만 관리" ON public.pets;
CREATE POLICY "본인 펫만 관리" ON public.pets AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- posts
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "공개 게시글 조회" ON public.posts;
CREATE POLICY "공개 게시글 조회" ON public.posts AS PERMISSIVE FOR SELECT TO public USING ((is_hidden = false));
DROP POLICY IF EXISTS "본인 글만 수정/삭제" ON public.posts;
CREATE POLICY "본인 글만 수정/삭제" ON public.posts AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "모두 조회 가능" ON public.profiles;
CREATE POLICY "모두 조회 가능" ON public.profiles AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "본인만 수정" ON public.profiles;
CREATE POLICY "본인만 수정" ON public.profiles AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = id));

-- records
ALTER TABLE public.records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "본인 기록만 관리" ON public.records;
CREATE POLICY "본인 기록만 관리" ON public.records AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- reminders
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "본인 알림만 관리" ON public.reminders;
CREATE POLICY "본인 알림만 관리" ON public.reminders AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- reports
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "신고 삽입" ON public.reports;
CREATE POLICY "신고 삽입" ON public.reports AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = reporter_id));
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- ⚠️  반드시 교체: 아래 UUID를 새 프로젝트 로그인 후 실제 UUID로 바꿔야 함
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
DROP POLICY IF EXISTS reports_select_admin ON public.reports;
CREATE POLICY reports_select_admin ON public.reports AS PERMISSIVE FOR SELECT TO public
  USING ((auth.uid() = ANY (ARRAY['99244f0e-6035-49df-9189-27caf6df9c89'::uuid, 'b8ea8060-898b-4b2a-a98e-897e90be7d1f'::uuid])));
DROP POLICY IF EXISTS reports_update_admin ON public.reports;
CREATE POLICY reports_update_admin ON public.reports AS PERMISSIVE FOR UPDATE TO public
  USING ((auth.uid() = ANY (ARRAY['99244f0e-6035-49df-9189-27caf6df9c89'::uuid, 'b8ea8060-898b-4b2a-a98e-897e90be7d1f'::uuid])));

-- saves
ALTER TABLE public.saves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "본인 저장만 관리" ON public.saves;
CREATE POLICY "본인 저장만 관리" ON public.saves AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = owner_id));

-- sighting_reports
ALTER TABLE public.sighting_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "목격 신고 조회" ON public.sighting_reports;
CREATE POLICY "목격 신고 조회" ON public.sighting_reports AS PERMISSIVE FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "목격 신고 작성" ON public.sighting_reports;
CREATE POLICY "목격 신고 작성" ON public.sighting_reports AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = reporter_id));
DROP POLICY IF EXISTS "reporter delete" ON public.sighting_reports;
CREATE POLICY "reporter delete" ON public.sighting_reports AS PERMISSIVE FOR DELETE TO public USING ((auth.uid() = reporter_id));

-- =====================================================
-- EDGE FUNCTIONS (별도 배포 필요)
-- =====================================================

-- 로컬 파일 위치: pawprint/supabase/functions/
-- 새 프로젝트에 Supabase CLI로 배포: supabase functions deploy --project-ref <새 프로젝트 ID>
--
-- 배포할 함수 목록:
-- 1. send-notification  → FCM 알림 (좋아요/댓글/팔로우/새글/채팅)
-- 2. moderate-images    → Google Cloud Vision 이미지 검열
-- 3. delete-account     → 계정 탈퇴 (Storage 파일 + auth.users 삭제)
-- 4. send-reminders     → 예방접종 알림 (매일 실행, Cron 설정 필요)
-- 5. send-birthday      → 생일 알림 (매일 실행, Cron 설정 필요)
--
-- 환경변수 (새 프로젝트 Dashboard → Settings → Edge Functions에서 동일하게 설정):
-- - GOOGLE_VISION_API_KEY         (moderate-images)
-- - FIREBASE_SERVICE_ACCOUNT      (send-notification, send-reminders, send-birthday) — JSON 문자열
-- - CRON_SECRET                   (send-birthday — 외부 무단 호출 방지)
-- ※ SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY는 Supabase가 자동 주입
--
-- ⚠️ send-reminders, send-birthday는 Cron Job 재등록 필요 (Dashboard → Database → Cron Jobs)
