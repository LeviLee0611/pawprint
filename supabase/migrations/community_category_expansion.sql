-- community_posts category check에 tip, question 추가
alter table public.community_posts
  drop constraint if exists community_posts_category_check;

alter table public.community_posts
  add constraint community_posts_category_check
  check (category in ('lost', 'found', 'rehome', 'looking', 'tip', 'question'));
