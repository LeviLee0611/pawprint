-- ================================================
-- chat_rooms 테이블
-- ================================================
create table if not exists public.chat_rooms (
  id              uuid default gen_random_uuid() primary key,
  post_id         uuid references public.community_posts(id) on delete cascade not null,
  author_id       uuid references public.profiles(id) on delete cascade not null,
  helper_id       uuid references public.profiles(id) on delete cascade not null,
  last_message_at timestamptz default now() not null,
  created_at      timestamptz default now(),
  unique (post_id, helper_id)
);

alter table public.chat_rooms enable row level security;

-- 참여자만 조회
drop policy if exists "채팅방 조회" on public.chat_rooms;
create policy "채팅방 조회" on public.chat_rooms
  for select using (
    auth.uid() = author_id or auth.uid() = helper_id
  );

-- helper만 방 생성 (author_id가 실제 해당 게시글 owner인지, 자기 자신과 채팅 불가 검증)
drop policy if exists "채팅방 생성" on public.chat_rooms;
create policy "채팅방 생성" on public.chat_rooms
  for insert with check (
    auth.uid() = helper_id
    and helper_id != author_id
    and exists (
      select 1 from public.community_posts p
      where p.id = post_id
        and p.owner_id = author_id
    )
  );

-- 클라이언트 update 권한 없음 — last_message_at은 trigger로 자동 갱신
drop policy if exists "채팅방 수정" on public.chat_rooms;

create index if not exists idx_chat_rooms_author   on public.chat_rooms(author_id);
create index if not exists idx_chat_rooms_helper   on public.chat_rooms(helper_id);
create index if not exists idx_chat_rooms_post     on public.chat_rooms(post_id);
create index if not exists idx_chat_rooms_last_msg on public.chat_rooms(last_message_at desc);

-- ================================================
-- chat_messages 테이블
-- ================================================
create table if not exists public.chat_messages (
  id         uuid default gen_random_uuid() primary key,
  room_id    uuid references public.chat_rooms(id) on delete cascade not null,
  sender_id  uuid references public.profiles(id) on delete cascade not null,
  content    text not null,
  created_at timestamptz default now()
);

alter table public.chat_messages enable row level security;

-- 방 참여자만 메시지 조회
drop policy if exists "채팅 메시지 조회" on public.chat_messages;
create policy "채팅 메시지 조회" on public.chat_messages
  for select using (
    exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and (r.author_id = auth.uid() or r.helper_id = auth.uid())
    )
  );

-- 방 참여자만 메시지 전송
drop policy if exists "채팅 메시지 전송" on public.chat_messages;
create policy "채팅 메시지 전송" on public.chat_messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and (r.author_id = auth.uid() or r.helper_id = auth.uid())
    )
  );

create index if not exists idx_chat_messages_room    on public.chat_messages(room_id);
create index if not exists idx_chat_messages_created on public.chat_messages(created_at);

-- ================================================
-- last_message_at 자동 갱신 트리거
-- ================================================
create or replace function public.update_chat_room_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
  set last_message_at = new.created_at
  where id = new.room_id;
  return new;
end;
$$;

drop trigger if exists trg_chat_messages_last_message on public.chat_messages;
create trigger trg_chat_messages_last_message
  after insert on public.chat_messages
  for each row execute function public.update_chat_room_last_message();

-- ================================================
-- Realtime 활성화 (멱등 — 이미 등록된 경우 무시)
-- ================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end;
$$;
