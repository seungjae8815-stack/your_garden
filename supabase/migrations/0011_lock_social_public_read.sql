-- 너의 정원 — 공개 읽기 잠금 (1-8)
-- 공개 피드(v2 소셜)가 아직 미완성인데 public read 정책이 살아 있어서,
-- '정원 공개'를 켠 사용자의 일기 본문이 누구나 열람 가능한 상태였다.
-- 게다가 위기 글 필터(entries.is_flagged)는 항상 false라 동작하지 않는다.
-- → v2 소셜을 모더레이션/신고와 함께 제대로 열기 전까지 public read 정책을
--    모두 제거해 노출 경로를 닫는다. (앱에서도 공개 토글을 숨김 — kSocialEnabled=false)
-- self 정책(profiles_self_all·plants_self_all·entries_self_all)은 유지되므로
-- 사용자는 자기 데이터를 그대로 읽고 쓴다. 솔로 앱 동작에는 영향 없음.
-- Supabase SQL Editor에 붙여넣고 Run.

drop policy if exists profiles_public_read on profiles;
drop policy if exists plants_public_read   on plants;
drop policy if exists entries_public_read  on entries;

-- 남아 있을 수 있는 공개 플래그를 비공개로 정규화 (노출 흔적 제거).
update profiles set is_public = false where is_public = true;

-- v2 재오픈 시: 위 세 정책을 모더레이션(is_flagged) 반영해 다시 만들고,
-- 앱의 kSocialEnabled를 true로 돌린다.
