-- 너의 정원 — 복구(claim_garden) 보강
-- 복구 코드로 정원을 되찾을 때 닉네임만 가져오던 것을,
-- 정원 이름(garden_name)과 공개 여부(is_public)까지 함께 가져오도록 수정.
-- (0007에서 garden_name이 추가됐지만 claim_garden이 갱신되지 않아 복구 시 이름이 사라졌음.)
-- Supabase SQL Editor에 붙여넣고 Run.

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

  -- 닉네임·정원 이름·공개 여부를 가져오고, 코드 소유를 현재 계정으로 이동
  update profiles
     set nickname    = (select nickname    from profiles where id = src),
         garden_name = (select garden_name from profiles where id = src),
         is_public   = (select is_public   from profiles where id = src),
         backup_code_hash = p_hash
   where id = me;
  update profiles set backup_code_hash = null where id = src;

  return true;
end;
$$;

revoke all on function claim_garden(text) from public;
grant execute on function claim_garden(text) to authenticated;
