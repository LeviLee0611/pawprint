# 댕냥스토리 — 프로젝트 노트

> 날짜별 일지는 `devlog.md` / 이 파일은 **현재 상태 기준 기능·구조 정리**

---

## 스택

| 영역 | 기술 |
|---|---|
| 모바일 앱 | Flutter (Android 우선, iOS 예정) |
| 백엔드 | Supabase (PostgreSQL + Storage + Edge Functions) |
| 인증 | Supabase Auth (Google OAuth, 카카오 네이티브) |
| 이미지 저장 | Supabase Storage (`post-images`, `pet-photos` 버킷) |
| 콘텐츠 검열 | Google Cloud Vision SafeSearch API (Edge Function 경유) |
| 공유 | share_plus |
| 위치 | geolocator |
| 앱 이름 | 댕냥스토리 (구: 포포와 토토) |

---

## 기능 개발

### 인증
- Google OAuth + 카카오 네이티브 로그인 (`loginWithKakaoTalk()`)
- 로그인 후 펫 등록 여부 체크 → 없으면 등록 유도 (PetGate)
- Supabase Email Confirmation OFF (카카오 미인증 이메일 대응)

### 펫 관리
- `pets` 테이블: id / owner_id / name / type(cat|dog) / breed / birth_date / gender / photo_url
- `AddPetScreen`: 종류 선택, 프로필 사진, 이름/성별/생일/품종 입력
- `PetScreen`: 등록 펫 카드 목록, FAB으로 추가

### 캘린더 & 건강 기록
- `records` 테이블: id / pet_id / type / value / note / recorded_at
- 기록 타입: 예방접종(health) / 몸무게(weight) / 건강 메모(note)
- 월별 기록 로딩 + 날짜 마커(오렌지 점), 날짜 탭 → 기록 목록
- `RecordsHistoryScreen`: 전체 기록 날짜별 그룹

### 피드 (일반 게시글)
- `posts` 테이블: id / owner_id / pet_id / content / image_url / image_urls / likes_count / is_hidden
- `comments` / `likes` / `saves` / `follows` 테이블 연동
- 피드 필터: 전체 / 팔로잉 / 고양이 / 강아지
- 카드 레이아웃: 뉴스형 (썸네일 88×88 우측, 텍스트 좌측)
- 사진 상세: 1장=contain 전체 너비 / 다중=PageView 캐러셀 + 도트 인디케이터
- 좋아요 optimistic update, 댓글 스레드, 저장(북마크)
- 인기 탭: likes_count 내림차순
- 팔로우: `follows` 테이블, `UserProfileScreen`에서 팔로우 버튼

### 커뮤니티 (나눔 & 실종 & 꿀팁 & 질문)
- `community_posts` 테이블: id / owner_id / category / title / content / image_urls / pet_name / pet_type / location / status / address / latitude / longitude
- 카테고리: `lost`(실종) / `rehome`(입양보내기) / `looking`(입양원해요) / `tip`(꿀팁/정보) / `question`(질문/고민)
- 탭 필터: 전체 / 실종 / 나눔&입양 / 꿀팁/정보 / 질문/고민
- 실종 글: GPS 위치 → Nominatim 역지오코딩(한국어 주소) + 상세에서 Google Maps 연결
- 목격 신고 (`sighting_reports`): 발견 위치(GPS) + 메모 → 실종 글에 누적 표시
- 글 옵션 ⋮: 공유 / 수정 / 삭제 / 신고 (내 글 vs 남의 글 분기)
- status 값: `open` / `resolved` / `hidden`
- 게시글 owner: "해결됨으로 표시" / "다시 모집하기" 토글 (tip/question 제외)
- 비소유자: "찾았어요! 연락하기" 등 카테고리별 버튼 → 1:1 채팅 시작

### 1:1 채팅
- `chat_rooms` 테이블: id / post_id / author_id / helper_id / last_message_at / created_at
  - unique(post_id, helper_id) — 게시글당 helper 1개 방
  - RLS: helper만 방 생성(author_id가 실제 게시글 owner 검증 + 자기 자신 채팅 불가), 참여자만 조회
  - last_message_at: DB trigger 자동 갱신 (클라이언트 update 권한 없음)
- `chat_messages` 테이블: id / room_id / sender_id / content / created_at
  - RLS: 방 참여자만 조회·전송
  - Supabase Realtime 활성화
- `ChatService`: getOrCreateRoom / getMyRooms / getMessages / sendMessage / subscribeToRoom
- `ChatRoomScreen`: 실시간 메시지, 날짜 구분선, 자동 스크롤
- `ChatListScreen`: 전체 채팅 목록, 마지막 메시지 시간

### 신고 시스템
- `reports` 테이블: reporter_id / target_type / target_id / reason
- `showReportSheet()`: 스팸 / 욕설 / 부적절한 콘텐츠 / 기타
- 신고 5회 누적 → DB 트리거 자동 숨김 처리
  - 피드: `posts.is_hidden = true`
  - 커뮤니티: `community_posts.status = 'hidden'`

---

## 보안

### 이미지 검열 (Google Cloud Vision SafeSearch)
- **위치**: Supabase Edge Function `moderate-images`
- **시점**: 이미지 Storage 업로드 직후, DB 저장 전
- **기준**: adult 또는 violence가 LIKELY / VERY_LIKELY
- **결과**: 부적절 시 업로드 파일 자동 삭제 + 예외 반환 → 글 저장 안 됨
- **적용 범위**: 피드 글쓰기, 커뮤니티 글쓰기
- **미적용**: 글 수정 시 이미지 교체 (커뮤니티 수정은 텍스트만 가능하므로 현재 해당 없음)
- **비용**: 월 1,000장 무료, 초과 시 $1.50/1,000장

### 텍스트 키워드 필터 (클라이언트 사이드)
- **위치**: `content_filter.dart` → 각 서비스의 `addPost()` 최상단
- **시점**: 이미지 업로드 전 (낭비 방지)
- **대상**: 불법 도박, 불법 대출, 마약, 성인 광고, 스팸 단축 URL
- **한계**: 특수문자 삽입·띄어쓰기 우회 가능 → 신고 시스템으로 보완

### RLS (Row Level Security)
- 모든 테이블 RLS 활성화
- 본인 데이터만 수정/삭제 가능
- 피드·커뮤니티는 로그인 유저 전체 읽기 허용

### API 키 보안
- Google Vision API 키: Supabase Edge Function 환경변수 (`GOOGLE_VISION_API_KEY`)
- Supabase anon key: `config.dart` (`.gitignore` 적용)

---

## 성능 최적화

### 이미지 업로드
- 순차 업로드 → `Future.wait()` 병렬 업로드
- 피드 / 커뮤니티 서비스 모두 적용
- 효과: 5장 기준 약 5배 단축

### 쿼리 최적화
- 좋아요·저장 여부: 게시글 ID 목록으로 일괄 조회 (`Future.wait`)
- 팔로우 필터: `inFilter('owner_id', ids)` — PostgREST 레벨 처리
- 인기 피드: `likes_count` 내림차순 (DB 인덱스 적용)

---

## DB 스키마 요약

| 테이블 | 주요 컬럼 |
|---|---|
| `profiles` | id, display_name, avatar_url |
| `pets` | id, owner_id, name, type, breed, birth_date, gender, photo_url |
| `records` | id, pet_id, type, value, note, recorded_at |
| `posts` | id, owner_id, pet_id, content, image_url, image_urls, likes_count, is_hidden |
| `comments` | id, post_id, owner_id, content, parent_id |
| `likes` | id, post_id, owner_id |
| `saves` | id, post_id, owner_id |
| `follows` | id, follower_id, following_id |
| `community_posts` | id, owner_id, category, title, content, image_urls, pet_name, pet_type, location, status, address, latitude, longitude |
| `sighting_reports` | id, post_id, reporter_id, address, latitude, longitude, note |
| `reports` | id, reporter_id, target_type, target_id, reason |
| `chat_rooms` | id, post_id, author_id, helper_id, last_message_at, created_at |
| `chat_messages` | id, room_id, sender_id, content, created_at |
| `fcm_tokens` | owner_id, token, updated_at |

---

## 인프라 & 비용 계획

### 현재
- Supabase Free tier (DB 500MB, Storage 1GB, Edge Function 500K req/월)
- Google Cloud Vision: 월 1,000장 무료

### 규모 성장 시
- Supabase Pro $25/월 → DB 8GB, Storage 100GB
- Vision API: DAU 1,000명 기준 약 $88/월 예상
- Storage 80GB 초과 시 Cloudflare R2 이전 고려 (다운로드 무료)
- 영상 지원 시: 첫 프레임 썸네일만 Vision 검사로 비용 최소화

---

## 미구현 / 예정

### ✅ 2026-06-09 완료
- 커뮤니티 카테고리 확장 (tip/question) + 카드 그리드 UI + 탭바 컬러 디자인
- GPS 좌표 → Nominatim 역지오코딩 (한국어 주소 표시)
- 1:1 채팅 시스템 전체 구현 (chat_rooms/chat_messages, RLS, Realtime, ChatService, ChatRoomScreen, ChatListScreen)
- 새 채팅 메시지 FCM 푸시 알림 (멀티 디바이스, cold start 라우팅 안전 처리)
- send-notification Edge Function 전 케이스 멀티 디바이스 지원
- flutter analyze 0 issues

### ✅ 2026-06-08 완료
- 전체 화면 디자인 시스템 통일 (AppColors/AppTextStyles/AppSpacing/AppRadius/AppShadows)
- 모든 탭 상단 그라데이션 AppBar 통일
- LocationService 신규 (ensurePermission / getCurrentPosition)
- Codex 피드백 전체 반영 + flutter analyze 0 issues
- community_posts DB 보정 마이그레이션 실행 완료

### 우선순위 높음
- [ ] 회원탈퇴 완전 처리 (`auth.users` 삭제 Edge Function + Storage 정리)
- [ ] 다중 펫 캘린더 스위처
- [ ] `LocationService.ensurePermission()` — 실종·발견 글쓰기 진입 시 연결

### 우선순위 중간
- [ ] 목격 신고 시 위치 기반 푸시 알림
- [ ] 글 수정 시 이미지 교체 + 검열 적용
- [ ] 좋아요·저장 버튼 애니메이션 (ScaleTransition)
- [ ] Nominatim → Edge Function 프록시 전환 (사용자 증가 시 1 req/sec 정책 대응)

### MVP 이후
- [ ] AdMob 광고 연동
- [ ] 프리미엄 구독 (펫 3마리 이상, 고급 통계)
- [ ] Firebase App Distribution 테스트 배포
- [ ] 앱스토어 등록 (iOS)
- [ ] Play Store 등록 (Android) — AAB 빌드 + 정식 서명 키
