# 내일 할 일 (2026-06-02)

## 1. 팔로우 / 팔로잉

- `follows` 테이블 추가 (follower_id, following_id)
- 피드 카드에서 닉네임/아바타 옆에 팔로우 버튼 표시
- 팔로우한 사람 글만 보는 "팔로잉 피드" 탭 or 필터 추가
- 팔로우 수 / 팔로워 수 프로필에 표시

## 2. 다른 유저 프로필 보기

- 피드 카드에서 닉네임/아바타 탭 → 해당 유저 프로필 화면으로 이동
- 현재 내 프로필 탭(ProfileScreen)이 아닌 **별도 UserProfileScreen** 생성
- UserProfileScreen에서 보여줄 것:
  - 유저 아바타 + 닉네임 + 펫 목록
  - 팔로우/팔로워 수
  - 팔로우 버튼
  - 그 유저가 올린 게시글 피드 (내 피드 탭이 아닌 별도)

## 3. 피드 강아지 / 고양이 필터

- 피드 상단에 필터 칩 추가: **전체 / 고양이 🐱 / 강아지 🐶**
- 필터 선택 시 해당 pet type 게시글만 표시
- posts 테이블의 pet_id → pets.type ('cat' | 'dog') 기준으로 필터링
- pet 없이 올린 글은 "전체"에만 표시

---

## 작업 순서 추천

1. `follows` 테이블 + RLS → Supabase SQL 실행
2. `PostService`에 팔로우 토글 / 팔로워 조회 메서드 추가
3. `UserProfileScreen` 생성
4. 피드 카드 닉네임 탭 → UserProfileScreen 연결
5. 피드 필터 칩 UI 추가
