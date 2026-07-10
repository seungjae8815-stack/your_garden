-- 너의 정원 — 앱 버전 게이트 설정 (강제/선택 업데이트 안내)
-- 앱이 시작 시 자기 빌드번호(versionCode)를 이 값과 비교한다.
--   현재 빌드 <  min_supported_build → 차단형 "업데이트 필요" (앱 진입 불가)
--   현재 빌드 <  latest_build (단, >= min) → 선택형 "새 버전 있어요" 넛지
--   그 외 → 아무것도 안 뜸
-- 민감정보가 아니므로 익명 사용자도 '읽기'만 가능하게 공개 read 허용(쓰기 불가).
-- 값은 새 버전을 낼 때마다 SQL Editor에서 UPDATE 로 바꾸면 된다.
--
-- Supabase SQL Editor에 붙여넣고 Run.

create table if not exists app_config (
  id                  int  primary key default 1,
  min_supported_build int  not null default 0,   -- 이 빌드번호 미만 = 강제 업데이트
  latest_build        int  not null default 0,   -- 최신 빌드번호 = 선택 넛지 기준
  latest_version      text,                       -- 표시용 버전명 (예: '1.0.3')
  update_url          text,                       -- 스토어 URL (비우면 앱 기본값 사용)
  update_message      text,                       -- 선택: 강제 화면 커스텀 문구
  updated_at          timestamptz not null default now(),
  constraint app_config_singleton check (id = 1)
);

alter table app_config enable row level security;

-- 공개 설정 테이블이라 누구나 읽기 허용(사용자 데이터 아님). 쓰기 정책은 없음 → API로 수정 불가.
drop policy if exists app_config_public_read on app_config;
create policy app_config_public_read on app_config
  for select using (true);

grant select on app_config to anon, authenticated;

-- 초기 1행: 현재 출시 빌드(5) 기준. min=0이라 지금은 아무도 강제되지 않음.
insert into app_config (id, min_supported_build, latest_build, latest_version)
values (1, 0, 5, '1.0.2')
on conflict (id) do nothing;

-- ── 새 버전 낼 때 사용 예시 ─────────────────────────────
-- 선택 권유만: (예: 빌드 5 = v1.0.3 출시)
--   update app_config set latest_build = 5, latest_version = '1.0.3', updated_at = now() where id = 1;
-- 강제 업데이트까지: (빌드 5 미만은 앱 못 쓰게)
--   update app_config set min_supported_build = 5, latest_build = 5, latest_version = '1.0.3',
--     update_message = '중요한 안정성 개선이 있어요. 새 버전으로 이어가 주세요.', updated_at = now() where id = 1;
