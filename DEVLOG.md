# 포포와 토토 개발 기록

## TODO

### 다음 할 일 (Flutter 모바일)
- [x] 캘린더 홈 화면 — 펫 없을 때 빈 화면 + 등록 유도
- [x] 캘린더 홈 화면 — 펫 있을 때 날짜별 기록 UI
- [x] 기록 추가 기능 — 예방접종(health), 몸무게(weight), 건강 메모(note)
- [x] 내 펫 화면 — 등록된 펫 목록 + 펫 추가 버튼
- [x] 피드 화면 — 스레드 스타일, 전체 유저 공개, 좋아요 + 댓글
- [x] 프로필 화면 — 유저 정보 + 설정 + 로그아웃 + 회원탈퇴 + 수정
- [x] 캘린더 UX — 날짜 탭 시 기록 먼저 표시, 상단 + 버튼으로 기록 추가
- [x] 프로필 통계 카드 탭 → 내 펫 / 전체 기록 화면으로 이동
- [x] 전체 기록 히스토리 화면 (RecordsHistoryScreen)

### 코드 리뷰 반영 완료 (2026-05-30)
- [x] posts 테이블에 `pet_id uuid references pets(id)` 추가 → `supabase_migration.sql` 실행 필요
- [x] `display_name` 통일 — post_model, post_service, profile_service 전부 수정
- [x] 피드 쿼리 join 복구 — `profiles(display_name, avatar_url)` + `pets(name, type)`
- [x] 기록 수 count 쿼리 효율화 — `.count(CountOption.exact)` 사용
- [x] 글 삭제 시 Storage 이미지 함께 삭제 — `_storagePath()` 헬퍼 + `deletePost(imageUrl:)`

### Supabase 대시보드에서 직접 실행 필요
```
-- supabase_migration.sql 내용을 SQL Editor에서 실행
alter table public.posts add column if not exists pet_id uuid references public.pets(id) on delete set null;
create policy if not exists "피드에서 펫 이름 조회 허용" on public.pets for select using (true);
```

### 남은 작업 (다음)
- [ ] **회원탈퇴 — auth.users 삭제** — profiles 삭제만으로는 auth 계정이 남음
  - Supabase Edge Function 필요: `supabase.auth.admin.deleteUser(userId)`
  - 탈퇴 시 Storage 파일(pet-photos, post-images) 정리도 함께
- [ ] **펫 편집 기능** — 내 펫 화면에서 이름/사진/품종 수정 (새 화면 필요)
- [ ] **다중 펫 캘린더 선택 UI** — 현재 첫 번째 펫만 표시, 펫 스위처 필요
- [ ] **피드 이미지 업로드 RLS 확인** — post-images Storage 버킷 정책 테스트

### 나중에 (MVP 이후)
- [ ] 광고 (AdMob) 연동
- [ ] 프리미엄 구독 (펫 3마리 이상, 고급 통계)
- [ ] 푸시 알림
- [ ] 브랜드 제휴
- [ ] Firebase App Distribution으로 테스트 배포

---

## 2026-05-30 (오후)

### 한 일
- **캘린더 UX 개선**
  - 날짜 탭 → 기록 목록 바로 표시 (바텀시트 자동 노출 제거)
  - 상단 `+` 아이콘 버튼 → 선택된 날짜(없으면 오늘)의 기록 추가
  - 기록 없는 날 빈 상태 UI + "기록 추가" 버튼
  - 기록 목록에 날짜 헤더 + 추가/삭제 버튼
  - `RecordService.getAllRecords()` 추가
  - `RecordsHistoryScreen` 신규 — 전체 기록 날짜별 그룹
- **피드 스레드 스타일 전면 재설계**
  - 카드 제거 → 아바타 좌측 + 콘텐츠 우측 (Threads/Twitter 스타일)
  - 전체 유저 공개 커뮤니티 피드 (앱 사용자 누구나 글/댓글)
  - 글쓰기는 펫 등록 유저만 (FAB, 미등록 시 비활성)
  - 좋아요 optimistic update, 댓글 스레드 스타일
- **프로필 화면 개선**
  - 통계 카드 클릭: 등록한 펫 → PetScreen, 총 기록 → RecordsHistoryScreen
  - 프로필 수정 화면 추가 (이름 + 사진 변경)
  - profiles 테이블 join 에러 → auth 메타데이터만 사용으로 수정
  - ListTile Material 경고 수정
- **기기 빌드 (Galaxy S25+)**
  - posts.pet_id FK 없음, profiles.full_name 컬럼 없음 → 로컬 매칭 + 메타데이터로 우회

---

## 2026-05-30 (오전)

### 한 일
- **캘린더 기록 기능 전체 구현**
  - `record_model.dart` — Record 모델 (type/emoji/label 포함)
  - `record_service.dart` — getRecordsForMonth / addRecord / deleteRecord
  - `add_record_screen.dart` — 기록 입력 화면 (예방접종, 몸무게, 건강 메모)
  - `calendar_screen.dart` — 펫 로딩 + 월별 기록 로딩 + 날짜 마커(점) + 날짜별 기록 목록
  - `record_bottom_sheet.dart` — 탭 시 type string 반환 → AddRecordScreen으로 이동
- **펫 없을 때 빈 화면 + 등록 유도 UI**
- **내 펫 화면 (PetScreen) 구현**
  - 펫 카드 목록 (사진/이모지 아바타, 이름, 종류, 품종, 나이 칩, 성별 칩)
  - 빈 상태 + FAB으로 펫 추가
- **프로필 화면 (ProfileScreen) 구현**
  - 유저 헤더 (소셜 아바타, 이름, 이메일)
  - 통계 (등록한 펫 수, 총 기록 수)
  - 설정: 알림 토글 (SharedPreferences)
  - 정보: 이용약관, 개인정보처리방침, 앱 버전
  - 계정: 로그아웃, 회원탈퇴 (profiles cascade delete)
- **피드 화면 (FeedScreen) 전체 구현**
  - `post_model.dart` — Post / Comment 모델 (profiles·pets join)
  - `post_service.dart` — getPosts / addPost / deletePost / toggleLike / getComments / addComment / deleteComment
  - `feed_screen.dart` — 글 목록 (optimistic 좋아요), 펫 없으면 FAB 비활성, pull-to-refresh
  - `add_post_screen.dart` — 펫 선택 + 내용 + 이미지 첨부 + Supabase Storage
  - `post_detail_screen.dart` — 글 상세 + 댓글 목록 + 댓글 입력 + 내 글/댓글 삭제

### 플로우
날짜 탭 → 바텀시트 → AddRecordScreen → 저장 → 캘린더 오렌지 점
피드 FAB → AddPostScreen → 저장 → 피드 목록 / 탭 → PostDetailScreen → 댓글

### 현재 상태
- 4개 탭 전체 MVP 완성 (캘린더, 피드, 내 펫, 프로필)
- Supabase records / posts / comments / likes / pets / profiles 테이블 연동
- 사진 기록(캘린더)은 미구현 — "곧 추가" 안내

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
