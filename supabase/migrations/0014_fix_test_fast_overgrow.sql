-- 너의 정원 — add_entry 버그 수정: 테스트 모드(p_test_fast)가 만개(stage 5)를
-- 넘어 6단계 이상으로 성장시키는 문제.
-- 기존: grew := p_test_fast or (stage<5 and ...) → test_fast면 stage 5에서도 성장.
-- stage 6이 되면 화면(단계 이름 배열)이 깨질 수 있다. (릴리스 빌드는 test_fast가
-- 항상 false라 실사용자 영향은 없고, 디버그/테스트에서만 발생)
-- 수정: 만개 전(stage<5)일 때만 성장하도록 공통 가드.
--
-- Supabase SQL Editor에 붙여넣고 Run. (0012를 덮어씀)

create or replace function add_entry(
  p_plant_id uuid,
  p_user_text text,
  p_mood int,
  p_topic_tags text[],
  p_emotion_tags text[],
  p_reply_grew text,
  p_reply_stay text,
  p_test_fast boolean default false
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  pl plants;
  grew boolean;
  reply text;
begin
  -- 본인 식물 행 잠금 (연타/동시요청 직렬화). RLS도 함께 적용됨.
  select * into pl from plants
   where id = p_plant_id and owner_id = auth.uid()
   for update;
  if not found then
    raise exception 'plant not found or not owned';
  end if;

  -- 만개 전(stage<5)일 때만, 테스트 모드거나 서버 시각(Asia/Seoul) 기준
  -- '오늘 아직 안 자랐으면' 성장.
  grew := pl.current_stage < 5 and (
            p_test_fast or
            pl.last_growth_at is null or
            (pl.last_growth_at at time zone 'Asia/Seoul')::date
              < (now() at time zone 'Asia/Seoul')::date
          );
  reply := case when grew then p_reply_grew else p_reply_stay end;

  insert into entries (
    plant_id, user_text, ai_empathy, ai_plant_voice,
    stage_when_added, mood, topic_tags, emotion_tags
  ) values (
    p_plant_id, p_user_text, '', reply,
    pl.current_stage, p_mood,
    case when array_length(p_topic_tags, 1) is null then null else p_topic_tags end,
    case when array_length(p_emotion_tags, 1) is null then null else p_emotion_tags end
  );

  if grew then
    update plants
       set current_stage = current_stage + 1,
           last_growth_at = now()
     where id = p_plant_id
     returning * into pl;
  end if;

  return jsonb_build_object('grew', grew, 'reply', reply, 'plant', to_jsonb(pl));
end;
$$;

revoke all on function add_entry(uuid, text, int, text[], text[], text, text, boolean) from public;
grant execute on function add_entry(uuid, text, int, text[], text[], text, text, boolean) to authenticated;
