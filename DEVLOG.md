# 냥발도장 개발 기록

## TODO
- [ ] Supabase 테이블 생성 (WEB_COMMUNITY_HARNESS.md 섹션 7 SQL 실행)
- [ ] Supabase Google Auth 프로바이더 활성화
- [ ] 로컬에서 npm run dev 실행 후 동작 확인
- [ ] Cloudflare Pages 배포 연결

---

## 2026-05-27

### 한 일
- Next.js 16 + Supabase + TypeScript 프로젝트 세팅
- Firebase 계획에서 Supabase + Cloudflare로 스택 변경
- 전체 파일 구조 구축 (components, hooks, lib, types)
- MVP 페이지 전부 작성 (피드, 글 작성, 글 상세, 프로필, 로그인)
- WEB_COMMUNITY_HARNESS.md 하네스 문서 작성
- GitHub push → LeviLee0611/pawprint

### 스택 확정
- Next.js 16 (App Router)
- Supabase (PostgreSQL, Auth, Storage)
- Tailwind CSS 4
- TypeScript
- Cloudflare Pages (배포)

### 메모
- `.env.local` Supabase URL + anon key 입력 완료
- `@cloudflare/next-on-pages` 패키지가 Next.js 16 아직 미지원 → 배포 시점에 해결
