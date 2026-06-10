# 댕냥스토리 데이터베이스 구조

> 마지막 업데이트: 2026-06-08

---

## 테이블 관계도

```
auth.users
    │
    └─→ profiles (1:1)
            │
            ├─→ pets (1:N)
            │     └─→ records (1:N)
            │
            ├─→ posts (1:N)
            │     ├─→ comments (1:N, 자기참조 대댓글)
            │     ├─→ likes (1:N)
            │     └─→ saves (1:N)
            │
            ├─→ community_posts (1:N)
            │     └─→ sighting_reports (1:N)
            │
            ├─→ fcm_tokens (1:N)
            └─→ reports (1:N)
```

---

## 테이블 목록

### profiles
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | auth.users.id와 동일 |
| display_name | TEXT | 표시 이름 (신규 가입 시 자동 설정) |
| avatar_url | TEXT | 프로필 사진 URL |

- **RLS**: 전체 조회 허용 / 본인만 수정
- handle_new_user 트리거로 가입 시 자동 생성

---

### pets
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| name | TEXT | 펫 이름 |
| type | TEXT | 'cat' \| 'dog' |
| breed | TEXT | 품종 |
| birth_date | DATE | 생일 |
| gender | TEXT | 성별 |
| photo_url | TEXT | 사진 URL |
| created_at | TIMESTAMPTZ | |

- **RLS**: 전체 조회 허용 (피드 join용) / 본인만 관리
- **인덱스**: `idx_pets_owner_id`

---

### records
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| pet_id | UUID FK→pets (nullable) | ON DELETE CASCADE, null = 공통 기록 |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| type | TEXT | health / weight / note / meal / grooming / play / bath / photo |
| value | NUMERIC | 값 (몸무게 등) |
| notes | TEXT | 메모 |
| photo_url | TEXT | 사진 URL |
| date | DATE | 기록 날짜 |
| created_at | TIMESTAMPTZ | |

- **RLS**: 본인 기록만 관리
- **인덱스**: `idx_records_pet_date`, `idx_records_owner_id`

---

### posts
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| pet_id | UUID FK→pets | ON DELETE SET NULL (선택) |
| content | TEXT | 본문 |
| image_url | TEXT | 단일 이미지 (하위 호환용) |
| image_urls | TEXT[] | 다중 이미지 URL 배열 |
| likes_count | INT DEFAULT 0 | 트리거 자동 관리, >= 0 |
| comments_count | INT DEFAULT 0 | 트리거 자동 관리, >= 0 |
| is_hidden | BOOLEAN DEFAULT false | 신고 5회 누적 시 자동 true |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

- **RLS**: `is_hidden = false`인 게시글만 조회 / 본인만 작성·수정·삭제
- **인덱스**: `idx_posts_owner_id`, `idx_posts_created_at DESC`

---

### comments
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| post_id | UUID FK→posts | ON DELETE CASCADE |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| parent_id | UUID FK→comments | 대댓글 (선택) ON DELETE CASCADE |
| content | TEXT | 댓글 내용 |
| created_at | TIMESTAMPTZ | |

- **RLS**: 전체 조회 / 본인 작성 / 본인 or 게시글 작성자 삭제
- **인덱스**: `idx_comments_post_id`, `idx_comments_parent_id`, `idx_comments_post_parent`

---

### likes
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| post_id | UUID FK→posts | ON DELETE CASCADE |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| created_at | TIMESTAMPTZ | |

- **UNIQUE**: (post_id, owner_id)
- **RLS**: 본인만 관리
- **인덱스**: `idx_likes_owner_id`, `idx_likes_post_id`

---

### saves
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| post_id | UUID FK→posts | ON DELETE CASCADE |
| created_at | TIMESTAMPTZ | |

- **UNIQUE**: (owner_id, post_id)
- **RLS**: 본인만 관리
- **인덱스**: `saves_owner_id_idx`, `saves_post_id_idx`

---

### follows
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| follower_id | UUID FK→profiles | 팔로우 하는 사람 |
| following_id | UUID FK→profiles | 팔로우 받는 사람 |
| created_at | TIMESTAMPTZ | |

- **UNIQUE**: (follower_id, following_id)
- **RLS**: 본인만 관리

---

### fcm_tokens
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| token | TEXT UNIQUE | 기기별 FCM 토큰 |
| updated_at | TIMESTAMPTZ | |

- **RLS**: 본인만 관리 / Edge Function은 서비스 롤 키로 전체 접근
- 멀티 디바이스 지원: 기기별 독립 토큰, 로그아웃 시 해당 기기 토큰만 삭제

---

### reports
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| reporter_id | UUID FK→auth.users | ON DELETE CASCADE |
| target_type | TEXT | 'post' \| 'comment' \| 'community_post' |
| target_id | UUID | 신고 대상 ID |
| reason | TEXT | 신고 사유 |
| created_at | TIMESTAMPTZ | |

- **UNIQUE**: (reporter_id, target_type, target_id) — 중복 신고 방지
- **RLS**: 본인 신고만 조회·삽입

---

### community_posts
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| owner_id | UUID FK→profiles | ON DELETE CASCADE |
| category | TEXT | 'lost' \| 'found' \| 'rehome' \| 'looking' \| 'tip' \| 'question' |
| title | TEXT | 제목 |
| content | TEXT | 내용 |
| image_urls | TEXT[] DEFAULT '{}' | 이미지 URL 배열 |
| pet_name | TEXT | 펫 이름 (선택) |
| pet_type | TEXT | 'cat' \| 'dog' (선택) |
| location | TEXT | 지역 (선택) |
| contact | TEXT | 연락처 (선택) |
| status | TEXT DEFAULT 'open' | 'open' \| 'resolved' \| 'hidden' |
| address | TEXT | 실종 위치 주소 |
| latitude | DOUBLE PRECISION | 위도 |
| longitude | DOUBLE PRECISION | 경도 |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

- **RLS**: `status != 'hidden'`인 게시글만 조회 / 본인만 작성·수정·삭제
- **인덱스**: `idx_community_posts_owner`, `idx_community_posts_category`, `idx_community_posts_created`, `idx_community_posts_status`

---

### sighting_reports
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID PK | |
| post_id | UUID FK→community_posts | ON DELETE CASCADE |
| reporter_id | UUID FK→profiles | ON DELETE CASCADE |
| address | TEXT | 목격 주소 |
| latitude | DOUBLE PRECISION | 위도 |
| longitude | DOUBLE PRECISION | 경도 |
| note | TEXT | 메모 |
| created_at | TIMESTAMPTZ | |

- **UNIQUE**: (post_id, reporter_id) — 게시글당 유저 1회 신고
- **RLS**: 전체 조회 / 본인만 작성
- **인덱스**: `idx_sighting_reports_post`

---

## 트리거

| 트리거 | 테이블 | 시점 | 동작 |
|---|---|---|---|
| handle_new_user | auth.users | AFTER INSERT | profiles 자동 생성 |
| update_likes_count | likes | AFTER INSERT/DELETE | posts.likes_count 증감 (0 이하 방지) |
| update_comments_count | comments | AFTER INSERT/DELETE | posts.comments_count 증감 (0 이하 방지) |
| trigger_auto_hide_on_reports | reports | AFTER INSERT | 신고 5회 누적 시 게시글 자동 숨김 |

---

## Edge Functions

| 함수명 | 역할 |
|---|---|
| `send-notification` | FCM 알림 발송 (좋아요·댓글·신고 등) |
| `moderate-images` | Google Cloud Vision SafeSearch로 이미지 검열 |

- 두 함수 모두 서비스 롤 키 사용 → RLS 우회
- `moderate-images`: GOOGLE_VISION_API_KEY 환경변수 필요

---

## Storage 버킷

| 버킷 | 용도 |
|---|---|
| `pet-photos` | 펫 프로필 사진 |
| `post-images` | 피드·커뮤니티 게시글 이미지 |
