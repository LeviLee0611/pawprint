# 냥발도장 개발 기록

## TODO

### 1단계 — 백엔드 연결 (다음 할 일)
- [ ] Supabase SQL Editor에서 테이블 생성 (WEB_COMMUNITY_HARNESS.md 섹션 7 SQL 실행)
- [ ] Supabase Dashboard → Authentication → Providers → Google 활성화
- [ ] Google Cloud Console에서 OAuth 클라이언트 ID/Secret 발급 후 Supabase에 입력
- [ ] Supabase Dashboard → Storage → `post-images` 버킷 생성 (Public)
- [ ] `npm run dev` 로컬 실행 후 로그인 동작 확인

### 2단계 — 기능 검증
- [ ] Google 로그인 → profiles 테이블에 유저 자동 생성되는지 확인
- [ ] 글 작성 → posts 테이블에 저장되는지 확인
- [ ] 이미지 업로드 → Supabase Storage에 저장되는지 확인
- [ ] 피드에서 글 목록 로드 확인
- [ ] 댓글 작성/삭제 확인
- [ ] 좋아요 토글 확인

### 3단계 — UI 다듬기
- [ ] 로딩 상태 전체 점검 (스피너 제대로 뜨는지)
- [ ] 빈 상태 화면 점검 (글 없을 때, 댓글 없을 때)
- [ ] 모바일 반응형 확인 (브라우저 창 줄여서 테스트)
- [ ] 이미지 없는 글 레이아웃 확인
- [ ] 에러 상황 처리 (네트워크 끊겼을 때 등)

### 4단계 — 배포
- [ ] Cloudflare Pages에 GitHub 레포 연결
- [ ] 환경변수 Cloudflare에 입력 (SUPABASE_URL, SUPABASE_ANON_KEY)
- [ ] 빌드 확인 (`npm run build` 로컬에서 먼저)
- [ ] 배포 후 실제 URL에서 동작 확인
- [ ] Supabase Auth에 Cloudflare 도메인 허용 URL 추가

### 5단계 — MVP 이후 (나중에)
- [ ] 글 검색 기능
- [ ] 유저 팔로우 시스템
- [ ] 글 저장 (북마크)
- [ ] 푸시 알림
- [ ] 카카오 로그인 추가
- [ ] 네이버 로그인 추가

---

## 2026-05-28

### 한 일
- GitHub에서 어제 작업 pull (Flutter mobile 코드 포함)
- 갤럭시 S25+ 와이파이 무선 디버깅 연결 (adb tcpip)
- Supabase DB 설계 및 테이블 생성
  - profiles, pets, records, posts, comments, likes 테이블
  - RLS 정책 전체 적용
  - 인덱스 추가 (records, posts, comments, likes)
  - updated_at 트리거 추가
  - Storage 버킷 생성 (pet-photos, post-images)
  - likes/comments count 자동 업데이트 트리거
- Google OAuth 로그인 구현 (Flutter)
  - Google Cloud Console에서 Web + Android OAuth 클라이언트 생성
  - Supabase Google Provider 설정
  - `app_links` 패키지로 딥링크 처리
  - `com.pawprint.mobile://login-callback/` 딥링크 스킴 등록
  - Android intent-filter 추가
  - 실기기(갤럭시 S25+) 로그인 테스트 성공

### 현재 상태
- 모바일: Google 로그인 완료, 메인 화면(캘린더) 진입 가능
- DB: 전체 스키마 완성, RLS + 인덱스 적용
- 웹: 아직 백엔드 미연결 (다음 작업)

### 메모
- Supabase Google Provider에는 반드시 **Web 클라이언트 ID** 사용 (Android ID 아님)
- Redirect URLs에 `com.pawprint.mobile://login-callback/` 등록 필수
- `config.dart`는 `.gitignore`에 포함됨 (Supabase URL, anon key, Web Client ID 보관)
- 카카오/네이버 로그인은 MVP 이후 추가 예정

---

## 2026-05-27

### 한 일
- Next.js 16 + Supabase + TypeScript 프로젝트 세팅
- Firebase 계획에서 Supabase + Cloudflare로 스택 변경
- 전체 파일 구조 구축 (components, hooks, lib, types)
- MVP 페이지 전부 작성 (피드, 글 작성, 글 상세, 프로필, 로그인)
- WEB_COMMUNITY_HARNESS.md 하네스 문서 작성
- GitHub push → LeviLee0611/pawprint
- DEVLOG.md 작성
- Flutter 모바일 앱 초기 세팅 (캘린더 UI + Supabase 연동 구조)
  - `mobile/` 디렉토리에 Flutter 프로젝트 생성
  - 일정 관리용 캘린더 화면 컴포넌트 작성
  - Supabase Flutter SDK 연결 준비
- GitHub PAT 인증 설정 완료 (Windows 자격 증명 관리자에 자동 저장)
- GitHub origin에 전체 코드 최종 푸시

### 스택 확정
- **웹:** Next.js 16 (App Router) + Supabase + Tailwind CSS 4 + TypeScript
- **모바일:** Flutter + Supabase
- **배포:** Cloudflare Pages (웹), 추후 앱스토어 (모바일)

### 현재 상태
- 웹: UI 코드 완성, Supabase 테이블/Auth/Storage 설정 미완료 → 백엔드 연결 전
- 모바일: 초기 구조만 잡힌 상태, 기능 개발 전

### 메모
- `.env.local` Supabase URL + anon key 입력 완료
- `@cloudflare/next-on-pages` 패키지가 Next.js 16 아직 미지원 → 배포 시점에 해결
- 다음 우선순위: Supabase 테이블 생성 (DEVLOG TODO 1단계)
