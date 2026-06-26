-- 너의 정원 v3 — 백업/복구 (복구 코드, 이메일 없음)
-- 코드 해시를 프로필에 저장하고, 다른 기기에서 그 코드로 정원 데이터를 가져온다.
-- Supabase SQL Editor에 붙여넣고 Run.

alter table profiles add column if not exists backup_code_hash text;
create index if not exists idx_profiles_backup_hash on profiles(backup_code_hash);

-- 코드 해시에 해당하는 정원(식물·기록)을 현재 로그인 사용자로 이전한다.
-- SECURITY DEFINER로 RLS를 우회하되, 정확한 해시가 있어야만 동작.
create or replace function claim_garden(p_hash text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  me  uuid := auth.uid();
  src uuid;
begin
  if me is null or p_hash is null or length(p_hash) < 16 then
    return false;
  end if;

  select id into src from profiles where backup_code_hash = p_hash limit 1;
  if src is null or src = me then
    return false;
  end if;

  -- 식물 소유자 이전 (기록 entries는 plant_id로 따라옴)
  update plants set owner_id = me where owner_id = src;

  -- 닉네임 가져오고, 코드 소유를 현재 계정으로 이동
  update profiles
     set nickname = (select nickname from profiles where id = src),
         backup_code_hash = p_hash
   where id = me;
  update profiles set backup_code_hash = null where id = src;

  return true;
end;
$$;

revoke all on function claim_garden(text) from public;
grant execute on function claim_garden(text) to authenticated;
