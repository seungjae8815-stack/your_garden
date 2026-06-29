-- 너의 정원 v3 — 온보딩 이름 짓기: 정원 이름 + 첫 식물 이름
-- 정원 이름은 프로필에, 식물 이름은 각 식물(감정 챕터)에 붙인다.
-- Supabase SQL Editor에 붙여넣고 Run.

alter table profiles add column if not exists garden_name text;
alter table plants   add column if not exists name text;
