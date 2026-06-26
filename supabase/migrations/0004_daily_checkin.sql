-- 너의 정원 v3 — 매일 체크인: 기분(mood) 기록
-- Supabase SQL Editor에 붙여넣고 Run.
-- mood: 1(아주 힘듦) ~ 5(좋음). 글 없이 기분만 묻을 수도 있어 user_text는 ''(빈문자) 허용.

alter table entries add column if not exists mood int check (mood between 1 and 5);
