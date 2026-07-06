-- 너의 정원 — 계정 완전 삭제 RPC (Google Play "계정 삭제" 요건)
-- 기존 '내 정원 데이터 삭제'는 plants만 지우고 profiles 행(닉네임·device_id·
-- 백업해시)과 auth 유저를 남겨서 Play 계정삭제 요건을 못 채웠음.
--
-- profiles 행을 지우면 FK on delete cascade로 plants·reactions(보낸 것)·visits
-- (방문한 것)가 함께 지워지고, plants 삭제로 entries·visits(방문받은 것)가,
-- entries 삭제로 reactions(받은 것)가 연쇄 삭제된다. 그 뒤 본인 auth 계정까지 지운다.
-- (profiles.id ↔ auth.users.id 사이엔 FK가 없어 둘 다 명시적으로 삭제해야 함.)
--
-- Supabase SQL Editor에 붙여넣고 Run.

create or replace function delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  -- 1) 앱 데이터: profiles 삭제 → plants/reactions/visits FK cascade로 연쇄 삭제
  delete from public.profiles where id = me;

  -- 2) 인증 계정까지 삭제 → 재설치해도 이 유저로 되돌아오지 않음.
  --    (auth.identities/sessions/refresh_tokens는 auth.users FK cascade로 정리)
  delete from auth.users where id = me;
end;
$$;

revoke all on function delete_account() from public;
grant execute on function delete_account() to authenticated;

-- 참고: 이 함수는 security definer라 소유자(SQL Editor 실행 시 postgres) 권한으로
-- 동작한다. 만약 auth.users 삭제에서 권한 오류가 나면, 함수 소유자를 auth 관리자로
-- 바꾸거나(alter function delete_account() owner to supabase_auth_admin) service_role
-- 키를 쓰는 Edge Function으로 대체하면 된다.
