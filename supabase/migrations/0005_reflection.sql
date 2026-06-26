-- 너의 정원 v3 — 만개 돌아보기: 거둘 때 남기는 마무리 한마디(감정 정리)
-- Supabase SQL Editor에 붙여넣고 Run.

alter table plants add column if not exists reflection text;
