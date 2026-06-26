-- 너의 정원 v3 — 자유 배치(드래그해 심기) 좌표 칼럼
-- Supabase SQL Editor에 붙여넣고 Run.
-- pos_x / pos_y : 0~1 정규화 좌표. (pos_y = 식물 바닥이 닿는 지면선)
-- 기존 pos_index 는 구버전 폴백용으로 남겨 둠.

alter table plants add column if not exists pos_x double precision;
alter table plants add column if not exists pos_y double precision;
