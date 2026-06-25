-- 너의 정원 v3 — 정원 배치(꾸미기) 칼럼
-- Supabase SQL Editor에 붙여넣고 Run.

alter table plants add column if not exists placed boolean not null default false;
alter table plants add column if not exists pos_index int;
