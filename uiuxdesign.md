# 댕냥스토리 UI/UX 디자인 가이드

> **앱 톤**: 따뜻하고 친근한 동네 커뮤니티. 딱딱하지 않고, 반려동물과 함께하는 일상이 편안하게 담기는 느낌.

---

## 색상 (Colors)

### 브랜드
| 이름 | 값 | 용도 |
|---|---|---|
| `primary` | `#FF9A3C` | 주요 버튼, 강조, 선택 상태 |
| `primaryLight` | `#FFE0B2` | 배경 강조, 칩 배경, 선택 표시 |
| `primaryDark` | `#E65100` | 누름 상태, 강한 강조 |

### 배경
| 이름 | 값 | 용도 |
|---|---|---|
| `background` | `#FFFAF5` | 앱 전체 배경 (크림색) |
| `surface` | `#FFFFFF` | 카드, 바텀시트, 다이얼로그 |
| `cardWarm` | `#FFFDF8` | 따뜻한 카드 배경 |

### 텍스트
| 이름 | 값 | 용도 |
|---|---|---|
| `textPrimary` | `#3E2723` | 제목, 본문 주요 텍스트 |
| `textSecondary` | `#8D6E63` | 부제목, 보조 정보 |
| `textHint` | `#BCAAA4` | placeholder, 시간 등 약한 텍스트 |

### 시맨틱 (기능별)
| 이름 | 값 | 용도 |
|---|---|---|
| `error` | `#E53935` | 삭제, 실종 신고, 경고 |
| `success` | `#43A047` | 입양/나눔 완료, 성공 |
| `warning` | `#FF8F00` | 입양 원해요, 주의 |
| `info` | `#1E88E5` | 위치 정보, 발견 신고 |

### 테두리 / 구분선
| 이름 | 값 | 용도 |
|---|---|---|
| `divider` | `#EDE8E3` | 섹션 구분선, 카드 테두리 |
| `brownLight` | `#D7CCC8` | 입력창 테두리 |

### 커뮤니티 카테고리 색상
| 카테고리 | 색상 |
|---|---|
| 실종 (`lost`) | `error` (#E53935) |
| 발견 (`found`) | `info` (#1E88E5) |
| 입양보내기 (`rehome`) | `success` (#43A047) |
| 입양원해요 (`looking`) | `warning` (#FF8F00) |

---

## 타이포그래피 (Typography)

### 원칙
- 한국어 본문은 줄간격 **1.6** (답답하지 않게)
- 제목류는 **1.3** (타이트하게)
- 최소 폰트 크기 **11px** (칩/뱃지 한정)

### 스케일
| 이름 | 크기 | 굵기 | 줄간격 | 용도 |
|---|---|---|---|---|
| `headline` | 18px | bold (700) | 1.3 | 화면 주요 제목 |
| `title` | 16px | w700 | 1.3 | 카드 제목, 섹션 헤더 |
| `subtitle` | 14px | w600 | 1.4 | 부제목, 라벨, 탭 |
| `body` | 14px | w400 | 1.6 | 본문 내용 |
| `bodySmall` | 13px | w400 | 1.6 | 보조 본문, 미리보기 |
| `caption` | 12px | w400 | 1.4 | 시간, 작성자, 보조 정보 |
| `chip` | 11px | w600 | 1.0 | 뱃지, 칩, 태그 |

### 색상 기본값
- 제목류 (`headline`, `title`): `textPrimary`
- 본문 (`body`, `bodySmall`): `textPrimary`
- 보조 (`subtitle`, `caption`): `textSecondary`
- 약한 정보: `textHint`

---

## 간격 (Spacing)

### 기본 단위: 4px

| 이름 | 값 | 용도 |
|---|---|---|
| `xs` | 4px | 아이콘-텍스트 사이, 칩 내부 |
| `sm` | 8px | 같은 그룹 내 요소 사이 |
| `md` | 12px | 카드 내 요소 간격 |
| `lg` | 16px | **화면 기본 horizontal padding**, 섹션 내 간격 |
| `xl` | 24px | 섹션 간 구분 |
| `xxl` | 32px | 큰 섹션 구분, 화면 상단 여백 |

### 화면 레이아웃
- **화면 좌우 padding**: 16px (전 화면 통일)
- **화면 상단 padding**: 12px
- **화면 하단 padding**: 100px (FAB / 네비게이션 바 여유)
- **카드 내부 padding**: 14px (가로), 12px (세로)

### 목록
- **카드 사이 간격**: 8px
- **섹션 사이**: 24px
- **항목 사이 (같은 카드 내)**: 8~12px

---

## 모서리 (Border Radius)

| 이름 | 값 | 적용 대상 |
|---|---|---|
| `radiusSm` | 8px | 작은 뱃지, 태그 |
| `radiusMd` | 12px | 입력창, 버튼, 작은 카드 |
| `radiusLg` | 16px | 카드, 바텀시트 내 컨테이너 |
| `radiusXl` | 20px | 바텀시트 상단, 다이얼로그 |
| `radiusPill` | 24px | 칩, 필터 버튼, 둥근 버튼 |

---

## 그림자 (Shadow)

카드 기본 그림자 (따뜻한 갈색 계열):
```
color: Color(0xFF8D6E63) @ 9% opacity
blurRadius: 16
offset: (0, 4)
```

강조 카드 (선택됨, 포커스):
```
color: primary @ 15% opacity
blurRadius: 12
offset: (0, 3)
```

---

## 컴포넌트

### 버튼
- **Primary 버튼**: 배경 `primary`, 텍스트 흰색, radius 12px, padding 14px×24px
- **Text 버튼**: 텍스트 `primary`, 배경 없음
- **Chip 버튼 (필터/선택)**: 선택 시 배경 해당 색상, 미선택 시 `surface` + `brownLight` 테두리, radius 24px (pill)
- **위험 버튼 (삭제)**: 텍스트 `error`, 배경 없음

### 카드
- 배경: `cardWarm` (#FFFDF8)
- 테두리: 없음 (그림자로 구분)
- radius: 16px
- shadow: 카드 기본 그림자

### 입력창
- 배경: `surface` (흰색)
- 테두리: `brownLight` (기본), `primary` 1.5px (포커스)
- radius: 12px
- hint 색상: `textHint`

### 아바타
| 용도 | 크기 |
|---|---|
| 피드 카드 | 36px (radius 18) |
| 게시글 상세 | 42px (radius 21) |
| 댓글 | 32px (radius 16) |
| 목격 신고, 작은 항목 | 24px (radius 12) |

### 바텀시트
- 상단 radius: 20px
- 배경: 투명 (패딩 내 흰색 컨테이너)
- 컨테이너 radius: 16px
- 항목 구분: Divider height 1px, color `divider`

### 다이얼로그
- radius: 20px
- 버튼: TextButton (취소: `textSecondary`, 확인: `primary` 또는 `error`)

### 빈 상태 (Empty State)
- 이모지/아이콘: 56px
- 제목: `title` 스타일 (16px, w700)
- 부제목: `bodySmall` 스타일 (13px, `textSecondary`)
- CTA 버튼 있을 경우: 상단 24px 간격

### 시간 표시 형식 통일
- 1분 미만: `방금`
- 1시간 미만: `N분 전`
- 24시간 미만: `N시간 전`
- 7일 미만: `N일 전`
- 그 이상: `M월 d일`
- 상세 화면(정확한 날짜 필요): `M월 d일 HH:mm`

---

## 인터랙션

### 탭 피드백
- 목록 아이템, 카드: `InkWell` + `splashColor: primaryLight @ 25%`
- 버튼: Flutter 기본 Material 리플
- GestureDetector는 피드백이 없으므로 **사용 금지** (순수 제스처가 필요한 경우 제외)

### 애니메이션
- 칩/선택 상태 변화: `AnimatedContainer` 150ms
- 페이지 전환: Flutter 기본
- 좋아요 등 액션 버튼: ScaleTransition 200ms

---

## 적용 체크리스트

모든 화면은 이 가이드를 기준으로:
- [ ] 색상은 `AppColors.*` 상수만 사용 (직접 Color() 금지)
- [ ] 폰트 크기/굵기는 위 스케일 기준 준수
- [ ] 화면 좌우 padding 16px 통일
- [ ] 카드 radius 16px, 입력창 radius 12px
- [ ] GestureDetector → InkWell 교체
- [ ] 빈 상태 UI 구조 통일
- [ ] 시간 표시 형식 통일
