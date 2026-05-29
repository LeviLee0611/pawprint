# 포포와 토토 개발 기록

## TODO

### 다음 할 일 (Flutter 모바일)
- [ ] 캘린더 홈 화면 — 펫 없을 때 빈 화면 + 등록 유도
- [ ] 캘린더 홈 화면 — 펫 있을 때 날짜별 기록 UI
- [ ] 기록 추가 기능 (텍스트, 사진, 기분 선택)
- [ ] 내 펫 화면 — 등록된 펫 목록 + 펫 추가 버튼
- [ ] 피드 화면 — 글 목록 + 글쓰기 (펫 없으면 글쓰기 비활성)
- [ ] 프로필 화면 — 유저 정보 + 로그아웃

### 나중에 (MVP 이후)
- [ ] 광고 (AdMob) 연동
- [ ] 프리미엄 구독 (펫 3마리 이상, 고급 통계)
- [ ] 푸시 알림
- [ ] 브랜드 제휴
- [ ] Firebase App Distribution으로 테스트 배포

---

## 2026-05-29

### 한 일
- **앱 브랜딩 확정**
  - 앱 이름: **포포와 토토**
  - 컬러: 크림 (#FDFBF5) + 오렌지 (#FF8C42)
  - 캐릭터: 포포(고양이) + 토토(강아지) 공식 채택
  - 슬로건: "매일의 기록이 사랑이 된다"
- **카카오 네이티브 로그인 완성**
  - `loginWithKakaoTalk()` 전환 (KakaoTalk 앱 연동)
  - Android 키 해시 등록 (`rxLZL3QGtmo6gZU1+BbyomM7mdc=`)
  - Supabase Kakao Provider Client ID → 네이티브 앱 키로 교체
  - Supabase Email Confirmation OFF (Kakao unverified email 대응)
- **로딩 화면 완성**
  - 포포&토토 이미지 통통 튀기기 애니메이션
  - 주변 🐾 발바닥 둥둥 떠다니는 효과
  - 배경색 이미지와 완전 매칭 (#FDFBF5)
- **펫 등록 화면 (AddPetScreen) 구현**
  - 상단: 포포/토토 얼굴 + "아이를 소개해주세요!" 헤더
  - 종류 선택: 포포발자국(오렌지)/토토발자국(브라운) 이미지 버튼
  - 프로필 사진 선택 (image_picker)
  - 이름 / 성별 / 생일(캘린더 전용) / 품종 입력
  - 상단 "나중에" 버튼으로 스킵 가능
  - Supabase pets 테이블 저장 성공
- **로그인 후 펫 체크 로직 (PetGate)**
  - 펫 없으면 → 펫 등록 화면
  - 펫 있으면 → 메인 앱

### Supabase pets 테이블 실제 컬럼명
- `birth_date` (birthday 아님)
- `gender` (text, 직접 추가)
- `photo_url` (profile_image_url 아님)
- `type` (text, 직접 추가) — 'cat' | 'dog'

### 현재 상태
- 로그인(Google + 카카오) → 펫 등록 → 메인 앱 진입 플로우 완성
- 메인 앱 내 각 화면은 아직 플레이스홀더

### 다음 할 일
- 캘린더 홈 화면 구현 (기록 핵심 기능)
- 내 펫 화면 (등록된 펫 목록)

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
- 카카오 로그인 구현 (Flutter)
  - `kakao_flutter_sdk_user` ^1.9.9 패키지 추가
  - `KakaoSdk.init()` + native app key 설정
  - `signInWithIdToken(provider: OAuthProvider.kakao)` 로 Supabase 연동
  - AndroidManifest에 Kakao scheme, AuthCodeHandlerActivity, queries 추가
  - Kakao 개발자 콘솔 OpenID Connect 활성화
  - 현재 `loginWithKakaoAccount()` 사용 중 (웹뷰 방식)
  - 프로필 화면 구현 (아바타, 닉네임, 이메일, 로그아웃)

### 현재 상태
- 모바일: Google + 카카오 로그인 완료, 메인 화면(캘린더) 진입 가능
- DB: 전체 스키마 완성, RLS + 인덱스 적용
- 웹: 아직 백엔드 미연결 (다음 작업)

### 다음 할 일
- 카카오 네이티브 로그인 (KakaoTalk 앱 연동) 전환
  - 카카오 개발자 콘솔에서 Android 플랫폼 등록 및 키 해시 등록 필요
  - 디버그 키 해시: `i6yFzEEMq8yQZsAAvEBtIfY6SDo=`
  - 새 콘솔 URL: `https://developers.kakao.com/console/app/1471106/` (플랫폼 메뉴 위치 변경됨)
  - 등록 후 `auth_service.dart`에서 `loginWithKakaoAccount()` → `loginWithKakaoTalk()` 전환

### 메모
- Supabase Google Provider에는 반드시 **Web 클라이언트 ID** 사용 (Android ID 아님)
- Redirect URLs에 `com.pawprint.mobile://login-callback/` 등록 필수
- `config.dart`는 `.gitignore`에 포함됨 (Supabase URL, anon key, Web Client ID, Kakao native key 보관)
- Kakao `User` 클래스 충돌 → `import ... hide User` 로 해결
- `loginWithKakaoTalk()`/`loginWithKakaoAccount()`에 `scopes` 파라미터 없음 (v1.x)

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
