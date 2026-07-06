-- 너의 정원 — 마음 묻기 원자화 RPC (2-10 race · 2-11 원자성 · 보너스 3-7 시계조작)
-- 기존엔 클라이언트가 stale 식물로 성장 여부를 판정하고(연타 시 하루 2단계),
-- entry insert와 plants update가 별개 왕복이라 중간 실패 시 불일치가 났다.
-- 또 성장 판정을 기기 시각으로 해서 시계를 되돌리면 성장 파밍이 가능했다.
--
-- → 하나의 트랜잭션에서: 식물 행을 FOR UPDATE로 잠그고(연타 직렬화),
--    서버 시각(Asia/Seoul 날짜)으로 '오늘 이미 자랐는지'를 판정하고,
--    entry를 넣고, 자랄 때만 단계를 올린다.
-- 한국어 답장(식물의 한마디)은 클라이언트 템플릿이라, 성장/유지 두 후보를 받아
--    서버가 실제 판정에 맞는 하나를 골라 저장·반환한다.
-- security invoker라 RLS(본인 식물만)가 그대로 적용된다.
-- Supabase SQL Editor에 붙여넣고 Run.

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

  -- 서버 시각(Asia/Seoul) 기준 '오늘 아직 안 자랐고 만개 전'이면 성장.
  grew := p_test_fast or (
            pl.current_stage < 5 and (
              pl.last_growth_at is null or
              (pl.last_growth_at at time zone 'Asia/Seoul')::date
                < (now() at time zone 'Asia/Seoul')::date
            )
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
