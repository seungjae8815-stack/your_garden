-- 너의 정원 v3 — 양분 태그: 체크인마다 '무엇이 양분이 됐나(주제)' + '지금 감정' 태그
-- 인사이트(마음 날씨 × 주제 상관, 감정 분포)의 원천 데이터.
-- Supabase SQL Editor에 붙여넣고 Run.

alter table entries add column if not exists topic_tags   text[];
alter table entries add column if not exists emotion_tags text[];
