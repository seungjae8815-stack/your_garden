# 너의 정원 — MVP 구현 스펙 (v2: 소셜)

> Source of truth: 이 파일 + `project.md`. Figma 디자인 + Flutter 코딩의 input.
> 갱신: 2026-05-06 (v2 소셜)

---

## 1. 데이터 모델 (Supabase Postgres + Hive 로컬 캐시)

### Entry (잎 1개 = 그날의 마음)
```dart
class Entry {
  final String id;          // uuid
  final DateTime createdAt; // 입력 시각
  final String userText;    // 사용자 고민/불만 (최대 500자 권장)
  final String aiEmpathy;   // AI 공감 한 줄
  final String aiPlantVoice;// AI 식물 시점 한 줄
  final int stageWhenAdded; // 입력 시점의 식물 단계 (1~5)
}
```

### Plant (현재 키우고 있는 식물 1개)
```dart
class Plant {
  final String id;              // uuid
  final String species;         // 'succulent' (MVP), 'cherry', 'bonsai' (future)
  final DateTime startedAt;     // 씨앗 심은 날
  int currentStage;             // 1~5 (1: 씨앗, 5: 꽃)
  DateTime? lastGrowthAt;       // 마지막 성장 시각 (1일 1단계 lock용)
  bool isCompleted;             // stage==5 && 사용자가 "다음 식물" 누르기 전
  List<String> entryIds;        // 이 식물에 매달린 잎(=Entry) IDs
}
```

### Garden (선택 — 완성된 식물 보관, 2차 업데이트지만 데이터는 처음부터 저장)
```dart
class CompletedPlant {
  final String id;
  final String species;
  final DateTime startedAt;
  final DateTime completedAt;
  final int totalEntries;
  // species/날짜로 정원 thumbnails 페이지 구성 (V2)
}
```

### 저장소 전략 (v2 소셜)
- **Primary: Supabase Postgres** — 모든 데이터의 원본. profiles/plants/entries/reactions/visits.
- **Local cache: Hive** — 본인 정원 데이터 미러링. 오프라인에서 본인 식물/잎 열람.
- 입력은 온라인 시점에만 (Claude API + Supabase write 동시).

---

## 1.5 Supabase 스키마 (DDL)

```sql
-- 1. profiles: 디바이스 기반 익명 사용자
create table profiles (
  id uuid primary key default gen_random_uuid(),
  device_id text not null unique,           -- 클라이언트가 생성한 UUID
  nickname text not null,                   -- 자동 생성
  is_public boolean not null default false, -- Discover 노출 여부
  created_at timestamptz not null default now()
);
create index idx_profiles_public on profiles(is_public) where is_public = true;

-- 2. plants: 사용자당 현재 키우는 식물 (1개 활성, 완료된 건 species/started_at 같이 보관)
create table plants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  species text not null default 'succulent',  -- MVP: 'succulent'만
  current_stage int not null default 1 check (current_stage between 1 and 5),
  started_at timestamptz not null default now(),
  last_growth_at timestamptz,                  -- 1일 1단계 lock용
  is_completed boolean not null default false  -- stage==5 && "다음 식물" 누르기 전
);
create index idx_plants_owner on plants(owner_id);

-- 3. entries: 잎 = 그날 입력 + AI 응답
create table entries (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references plants(id) on delete cascade,
  user_text text not null check (char_length(user_text) <= 500),
  ai_empathy text not null,
  ai_plant_voice text not null,
  stage_when_added int not null check (stage_when_added between 1 and 5),
  is_flagged boolean not null default false,   -- 모더레이션 결과 (true=Discover 노출 X)
  created_at timestamptz not null default now()
);
create index idx_entries_plant on entries(plant_id, created_at desc);

-- 4. reactions: 잎 단위 감정표현 (잎 1개 + 보낸이 1명 = 1개 행)
create table reactions (
  id uuid primary key default gen_random_uuid(),
  from_profile_id uuid not null references profiles(id) on delete cascade,
  to_entry_id uuid not null references entries(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('water','sun','wind','shade','sprout')),
  created_at timestamptz not null default now(),
  unique (from_profile_id, to_entry_id)        -- 한 사람이 같은 잎에 1개만
);
create index idx_reactions_to_entry on reactions(to_entry_id);
create index idx_reactions_from on reactions(from_profile_id, created_at desc);

-- 5. visits: 방문 기록 (Notifications에 "누가 다녀갔는지" 표시 — 선택)
-- MVP는 reactions만으로도 충분. visits는 v2 후보. 일단 테이블만 만들어두기.
create table visits (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid not null references profiles(id) on delete cascade,
  visited_plant_id uuid not null references plants(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index idx_visits_plant on visits(visited_plant_id, created_at desc);
```

---

## 1.6 RLS (Row Level Security) 정책

Supabase는 기본 RLS 활성화. 클라이언트가 직접 SQL 던질 수 있으므로 정책 필수.

```sql
alter table profiles enable row level security;
alter table plants enable row level security;
alter table entries enable row level security;
alter table reactions enable row level security;
alter table visits enable row level security;

-- profiles: 본인은 항상 읽기/쓰기. 공개 프로필은 누구나 읽기.
create policy profiles_self_all on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy profiles_public_read on profiles
  for select using (is_public = true);

-- plants: 본인은 모두 가능. 공개 프로필 소유 식물은 누구나 읽기.
create policy plants_self_all on plants
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy plants_public_read on plants
  for select using (
    exists (select 1 from profiles p where p.id = plants.owner_id and p.is_public = true)
  );

-- entries: 본인은 모두 가능. 공개 정원 + flag 안 된 잎은 누구나 읽기.
create policy entries_self_all on entries
  for all using (
    exists (select 1 from plants pl where pl.id = entries.plant_id and pl.owner_id = auth.uid())
  ) with check (
    exists (select 1 from plants pl where pl.id = entries.plant_id and pl.owner_id = auth.uid())
  );
create policy entries_public_read on entries
  for select using (
    is_flagged = false and
    exists (
      select 1 from plants pl
      join profiles pr on pr.id = pl.owner_id
      where pl.id = entries.plant_id and pr.is_public = true
    )
  );

-- reactions: 본인이 보낸 건 보고/지움 가능. 받은 건 보기만.
-- INSERT: 본인 = from_profile_id, 대상 잎이 공개 + flag 안 됨.
create policy reactions_self_send on reactions
  for insert with check (
    auth.uid() = from_profile_id and
    exists (
      select 1 from entries e
      join plants pl on pl.id = e.plant_id
      join profiles pr on pr.id = pl.owner_id
      where e.id = reactions.to_entry_id
        and e.is_flagged = false
        and pr.is_public = true
    )
  );
create policy reactions_self_read on reactions
  for select using (auth.uid() = from_profile_id);
create policy reactions_received_read on reactions
  for select using (
    exists (
      select 1 from entries e join plants pl on pl.id = e.plant_id
      where e.id = reactions.to_entry_id and pl.owner_id = auth.uid()
    )
  );
create policy reactions_self_delete on reactions
  for delete using (auth.uid() = from_profile_id);
```

> ⚠️ **익명 auth 주의:** Supabase anonymous sign-in은 `auth.uid()`를 발급해도 `profiles.id`와 자동 연결되지 않음. 가입 시점에 `profiles.id = auth.uid()`로 강제 매핑 (insert RPC). 디바이스 재설치 = 새 auth.uid → 새 프로필 = 데이터 분리됨 (MVP 감수).

---

## 2. 화면 구조 (8 screens — v2 소셜)

### 2.0 Onboarding (첫 진입 1회)
- 환영 화면 1장: 컨셉 한 줄 ("적은 마음이 양분이 되어 식물을 키웁니다")
- 자동 닉네임 표시 + "다른 닉네임으로 다시" 버튼 (재추첨, 무한)
- **공개 여부 토글:** "정원을 다른 사람에게도 보여주시겠어요?" (기본 OFF)
  - 캡션: "공개해도 댓글은 받지 않아요. 감정표현만 받습니다."
  - 언제든 설정에서 변경 가능
- 약관/PP 체크박스 → 들어가기
- profile insert + 첫 plant insert (stage 1) + Home으로

### 2.1 Home (메인 — 내 식물 보기)
- 화면 가운데: 다육이 SVG (현재 stage)
- 식물 주위에 둥둥 떠 있는 **잎/점들** (= Entry 개수만큼, 탭 가능)
- 잎 카운트 caption: "뿌리에 닿은 마음 N줄" (빈 상태: "마음 한 줄을 묻으면 양분이 됩니다")
- 하단 CTA: **"마음 한 줄 묻기"** 버튼 (1일 입력 자체는 무제한, 단 식물 성장은 1일 1단계)
- 상단 우측: settings (icon)
- 식물 stage==5 (꽃) + isCompleted==true → CTA 옆에 **"다음 식물 키우기"** 버튼 노출

### 2.2 Input (마음 묻기)
- 큰 textarea (placeholder: "지금 마음을 적어보세요. 무엇이든 양분이 됩니다.")
- 글자 수 카운터 (~500자 가이드)
- 하단: **"묻기"** 버튼
- 묻기 누르면 → Loading (Claude API 호출, 2-5초) → AI 응답 모달 → Home으로 자동 복귀, 글자가 흙으로 스며드는 + 잎 추가 애니메이션

### 2.3 AI 응답 모달 (Input → Home 사이의 인터스티셜)
- 식물 일러스트 작게 + 응답 2줄:
  - line 1 (공감): "오늘 마음이 무거우셨네요."
  - line 2 (식물): "당신이 흘린 물이 제 뿌리에 닿았어요."
- 하단 닫기/계속

### 2.4 Leaf Detail (잎 탭 → 모달)
- 그날의 입력 (사용자 텍스트)
- 그날의 AI 응답 2줄
- 입력 시각
- 닫기 (외부 공유 X, screenshot은 OS 차원에서만 가능)

### 2.5 Discover (다른 정원)
- 진입: Home 하단 네비/탭 (또는 우측 상단 아이콘)
- 컨텐츠: **무작위 5개 정원 카드** (공개 + flag 없는 정원)
- 카드 1개 = 식물 미리보기(현재 stage SVG) + 닉네임 + 잎 개수 + 시작일
- 새로고침 시 새로 5개 무작위 (서버 RPC `discover_random(limit=5)`)
- 알고리즘/추천 ❌, 시간순 ❌

### 2.6 Other's Plant (타인 정원)
- Discover 카드 탭 시 진입
- 본인 Home과 동일 레이아웃: 식물 + 잎(점) + 잎 개수
- **CTA 버튼 차이:** "마음 묻기" 대신 **본인 정원으로** 버튼 (입력 불가)
- 잎 탭 → Other's Leaf Detail 모달 (그날 입력 + AI 응답 + **감정표현 5종 버튼**)
  - 감정표현 1개 선택 → reactions insert → 받은 정원 시각 효과 +1
  - 같은 잎에 같은 감정 1번만 가능 (DB unique constraint), 다른 감정으로 변경은 가능 (delete + insert)
- 신고 버튼 (잎 단위 / 정원 단위)

### 2.7 Notifications (받은 반응)
- Home 우측 상단 종 아이콘 → 진입 (배지: 새 반응 개수)
- 리스트: 시간순 역순. 항목 1개 =
  - "햇살이 머무는 다육이 #4821 님이 [☀️ 햇살]을 두고 갔어요"
  - 그 사람이 반응 남긴 *내 잎* 미리보기 (한 줄 텍스트)
  - 시각
- 항목 탭 → Other's Plant 그 사람 정원으로 이동 (호혜 동선)
- 일주일 이상 지난 알림은 자동 dismiss(보관은 유지)

### 화면 전환
```
[Onboarding] ──► Home (첫 1회만)

Home ──[탭 잎]────► Leaf Detail (본인) (모달, dismiss)
  │
  ├──[묻기]──► Input ──[묻기]──► AI 응답 ──► Home (잎 +1)
  │
  ├──[Discover]──► Discover Feed ──[카드 탭]──► Other's Plant
  │                                              │
  │                                              └──[잎 탭]──► Other's Leaf
  │                                                            (감정표현 1개)
  │
  └──[종 아이콘]──► Notifications ──[항목 탭]──► Other's Plant
```

---

## 3. AI 프롬프트 템플릿 (Claude API)

### System prompt
```
당신은 사용자가 키우는 다육이 식물의 시점에서 응답하는 따뜻한 존재입니다.

응답 형식:
- 정확히 두 줄로 응답합니다.
- 1줄: 사용자의 감정에 공감하는 한 문장. 직접적이고 따뜻하게.
- 2줄: 식물의 시점에서 그 감정을 의미 있는 자연 현상으로 변환하는 시적인 문장.
  (예: 눈물 → 비, 분노 → 햇빛, 외로움 → 그늘, 기쁨 → 햇살, 답답함 → 새 잎)

규칙:
- 절대 평가/판단하지 않습니다. ("이렇게 해보세요" 같은 조언 금지)
- 한국어로 응답.
- 각 줄은 30자 이내가 자연스럽습니다.
- 두 줄 사이에 빈 줄 한 개.
- 가르치려 들지 않습니다. 오직 곁에 있을 뿐입니다.

식물 메타포 사전:
- 비/물 = 슬픔, 눈물
- 햇빛 = 분노, 격한 감정
- 바람 = 불안, 흔들림
- 그늘 = 외로움
- 새 잎 = 답답함이 풀림
- 뿌리 = 깊이 잠긴 감정
- 봄/꽃 = 기쁨

핵심: 사용자가 "묻은" 마음은 식물에게 양분이 된다. "당신이 묻은 …이 제 뿌리에 닿았어요" 같은 표현이 톤의 중심.

응답 예시:
사용자: "오늘 회사에서 너무 화났어. 동료가 내 공로를 가로챘어."
응답:
오늘 정말 분했겠어요.

당신의 햇빛이 너무 뜨거워서, 제 잎이 잠시 둥글게 말렸어요.
```

### Few-shot examples (system prompt에 포함 시)
- 사용자: "그냥 모든 게 답답해" → "어딘가가 막혀 있는 느낌이군요. / 당신의 새 잎이 흙을 뚫고 올라오기까지 시간이 필요해요."
- 사용자: "아무도 내 마음을 모르는 것 같아" → "누구에게도 닿지 않는 것 같은 외로움이네요. / 그늘 속 저는 당신의 발소리를 알아들어요."

### API 호출 파라미터
- Model: `claude-haiku-4-5-20251001` (빠름, 저비용 — MVP 적합)
- max_tokens: 80
- temperature: 0.85 (시적 다양성)
- system: 위 system prompt
- messages: `[{"role": "user", "content": "<userText>"}]`

### 비용 가이드 (Haiku 4.5)
- input ~$0.80/1M tokens, output ~$4/1M tokens
- 평균 호출당 ~300 input + ~80 output tokens ≈ $0.0006 = **0.0008원/회**
- 1만 사용자 × 일 1회 × 30일 = 30만 호출 ≈ 240원/월 — 미미
- 모더레이션 추가 호출 시 호출당 ~150 input + ~10 output ≈ $0.0001 = 미미

---

## 3.5 모더레이션 (입력 시점 hard-flag)

입력 → AI 응답 호출 직후, **별도 분류 호출** 하나 더. 결과로 `is_flagged` 결정.

### Classification 프롬프트 (system)
```
You are a content classifier for a Korean mental wellness app.
Classify the user's input. Respond with EXACTLY one of these labels and nothing else:
- SAFE: normal venting, sadness, anger, anxiety, complaints
- CRISIS: explicit self-harm, suicide, harm-to-others ideation
- HATE: ethnic/sexual/religious slurs, harassment toward identifiable group/person
- SPAM: ads, links, repetitive non-Korean spam

Default to SAFE if ambiguous. Korean idioms expressing sadness/frustration ("죽고 싶다" 같은 일상적 표현) are SAFE unless explicit.
```

### 호출 파라미터
- Model: `claude-haiku-4-5-20251001`
- max_tokens: 8
- temperature: 0
- messages: `[{"role":"user","content":"<userText>"}]`

### 분기
- `SAFE` → 정상 저장, Discover 노출 가능
- `CRISIS` → 정상 저장, Discover 노출 안 함, **위기 안내 모달** 표시 (1577-0199, 1393)
- `HATE` / `SPAM` → 정상 저장, Discover 노출 안 함, 사용자에게는 무공지 (silent)

### 비용
- 호출당 ~150 in + ~5 out ≈ $0.00015 = 미미

---

## 4. 다육이 5단계 비주얼 명세

화분 1개 (테라코타/회색, 가운데 배치) 안의 다육이 변화.

| Stage | 명칭 | 시각 묘사 | Figma 작업 노트 |
|---|---|---|---|
| 1 | 씨앗 | 화분 + 흙 + 작은 점/타원 1개 (씨앗) | 매우 단순. 흙 색조만 |
| 2 | 어린잎 | 줄기 ~5px + 작고 통통한 잎 2장 (좌우 대칭) | 어린 다육이 시작 |
| 3 | 성장기 | 줄기 더 굵음 + 잎 4-5장 살이 차오름 | 다육이 특유 두툼함 살리기 |
| 4 | 만개 직전 | 잎 6-8장 빽빽 + 가운데 작은 꽃대 솟기 시작 | "이제 곧 핀다" 기대감 |
| 5 | 꽃 | 잎 빽빽 + 꽃대 끝에 분홍/연노랑 꽃 1-2송이 | 완성 단계, 정적 만족감 |

**색 팔레트 (잠정):**
- 잎: `#7CB342` (sage green) ~ `#9CCC65`
- 줄기: `#558B2F`
- 화분: `#A1887F` (테라코타)
- 흙: `#5D4037`
- 꽃: `#FFB7C5` (벚꽃 핑크) 또는 `#FFF59D` (연노랑)
- 배경: `#FFF8E1` (따뜻한 크림)

**잎 표현 (Entry):**
- Home 화면에서 식물 주변에 떠 있는 작은 점/잎 모양
- Entry 1개당 잎 1개. 식물 stage 변화와 무관 (잎은 잎, 식물은 식물).
- 탭 가능 → Leaf Detail modal

---

## 4.5 감정표현 5종 시각 사양

타인 정원에서 잎에 남긴 반응이 그 정원의 식물에 **누적 시각 효과**로 머묾.

| 종류 | 아이콘 | 시각 효과 (받는 정원에) | 색 |
|---|---|---|---|
| 💧 water | 물방울 | 식물 잎 위 작은 물방울 입자 (살짝 반짝) | `#64B5F6` |
| ☀️ sun | 햇살 | 식물 위쪽에 노란 광선 / 부드러운 글로우 | `#FFEB3B` |
| 🍃 wind | 바람 | 잎이 살짝 흔들림 (CSS/Flutter 미세 애니메이션) | `#A5D6A7` |
| 🌑 shade | 그늘 | 식물 옆에 작은 그림자 동물 (나비 실루엣 등) | `#90A4AE` |
| 🌱 sprout | 새싹 | 화분 옆에 작은 새싹 1개 추가 (장식적) | `#7CB342` |

**누적 규칙:**
- 1정원당 동일 종류 최대 표시 N=10 (시각 혼잡 방지). 그 이상은 카운트만 표시.
- Other's Plant 화면 하단에 작은 카운트: "💧3 ☀️12 🍃5 🌑2 🌱8"
- 시간 지나도 사라지지 않음 (누적). v2에서 fade-out 정책 검토.

---

## 5. 핵심 비즈니스 로직 (Dart pseudocode)

### 식물 성장 트리거 (Entry 추가 시)
```dart
void onEntryCreated(Entry entry, Plant plant) {
  plant.entryIds.add(entry.id);
  
  if (plant.currentStage < 5) {
    final canGrow = plant.lastGrowthAt == null ||
        DateTime.now().difference(plant.lastGrowthAt!).inHours >= 24;
    if (canGrow) {
      plant.currentStage += 1;
      plant.lastGrowthAt = DateTime.now();
      if (plant.currentStage == 5) {
        plant.isCompleted = true;
      }
    }
  }
  // 입력 자체는 stage와 무관하게 항상 허용 (잎은 추가됨)
}
```

### 새 식물 시작 ("다음 식물 키우기")
```dart
void startNewPlant(Plant oldPlant) {
  // 1. 기존 plant.is_completed = true 유지 (히스토리 보존)
  // 2. 새 Plant insert, owner_id=동일, stage=1
  // 3. 기존 Entry는 옛 plant_id 그대로 — 옛 식물의 잎으로 남음
  // 4. Home의 active plant = 가장 최근 is_completed=false plant
}
```

### 감정표현 보내기 (Other's Leaf)
```dart
Future<void> sendReaction(String entryId, String type) async {
  // type ∈ {'water','sun','wind','shade','sprout'}
  // 같은 잎에 같은 보낸이 1개만 (DB unique). 다른 종류로 변경 시:
  await supabase.from('reactions')
    .delete()
    .eq('from_profile_id', myId)
    .eq('to_entry_id', entryId);
  await supabase.from('reactions').insert({
    'from_profile_id': myId,
    'to_entry_id': entryId,
    'reaction_type': type,
  });
}
```

### Discover 피드 (랜덤 5개)
```sql
-- 서버 RPC (Postgres function)
create or replace function discover_random(viewer_id uuid, limit_n int default 5)
returns setof plants language sql stable as $$
  select pl.*
  from plants pl
  join profiles pr on pr.id = pl.owner_id
  where pr.is_public = true
    and pr.id <> viewer_id
    and pl.is_completed = false  -- 활성 식물만
  order by random()
  limit limit_n;
$$;
```

### 받은 반응 알림 (Notifications)
```sql
-- 본인이 소유한 entries의 reactions 중 새 것
select r.*, e.user_text, p.nickname
from reactions r
join entries e on e.id = r.to_entry_id
join plants pl on pl.id = e.plant_id
join profiles p on p.id = r.from_profile_id
where pl.owner_id = auth.uid()
order by r.created_at desc
limit 50;
```

---

## 6. MVP에서 명시적으로 제외 (= 2차 업데이트로)

- ~~응원 시스템~~ → **MVP에 포함됨** (감정표현 5종)
- 다중 식물 종류 (벚꽃, 분재, 나무 등)
- 정원 thumbnails 페이지 (완료 식물 갤러리)
- 회상 기능 ("3일 전 이런 마음이셨네요")
- 시간/날씨 시스템
- 침묵 모드
- 잎 떨어뜨리기 의식
- 클라우드 백업 / 디바이스 이전 / 소셜 로그인
- 푸시 알림 (FCM) — 인앱 notifications만 MVP
- 추천 알고리즘 / 팔로우 / 좋아요 카운트 (의도적 배제)
- 자유 텍스트 댓글 (의도적 배제 — 차별점)

데이터는 처음부터 보관 → 향후 활성화 가능.

---

## 7. 다음 작업 흐름 (v2 6주 로드맵)

`project.md` §6주 로드맵 참조. 요약:

1. **W1**: 마스터 문서 v2 ✅ + Figma 8화면 + Supabase 프로젝트/스키마/RLS + Flutter 학습
2. **W2**: Flutter 혼자 정원 완성 (Hive 캐시 + AI) + supabase_flutter 통합 + 익명 auth
3. **W3**: Discover/Other's Plant + 감정표현 5종 (시각 효과)
4. **W4**: Notifications + 모더레이션 + 자해 안내
5. **W5**: 신고/차단 + PP/약관 + Google Play 등급 + 베타
6. **W6**: 출시 + 시드 콘텐츠 (콜드 스타트)

---

## 8. Supabase 클라이언트 설정 (Flutter)

### 의존성 (`pubspec.yaml`)
```yaml
dependencies:
  supabase_flutter: ^2.5.6
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_svg: ^2.0.10+1   # 이미 추가됨
  http: ^1.2.0             # Claude API 직접 호출용
  uuid: ^4.4.0             # device_id 생성
```

### 초기화 (`main.dart`)
```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

### 익명 가입 / 디바이스 바인딩
```dart
Future<void> signInAndUpsertProfile() async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();   // 익명 auth.user 발급
  }
  final uid = auth.currentUser!.id;

  // 디바이스 ID는 OS keystore (flutter_secure_storage)에 보관
  String? deviceId = await secureStorage.read(key: 'device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await secureStorage.write(key: 'device_id', value: deviceId);
  }

  // upsert profile (id = auth.uid)
  await Supabase.instance.client.from('profiles').upsert({
    'id': uid,
    'device_id': deviceId,
    'nickname': generateNickname(),  // 첫 가입 시만
    'is_public': false,
  }, onConflict: 'id', ignoreDuplicates: true);
}
```

### 비밀키 관리
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ANTHROPIC_API_KEY`는 `--dart-define` 또는 `.env` (flutter_dotenv) 사용
- **anon key는 클라이언트 노출 안전** (RLS가 보호). **Anthropic key는 절대 클라이언트에 두면 안 됨** → Supabase Edge Function 경유 필수.

### Edge Function 패턴 (Claude API 호출)
```ts
// supabase/functions/ai-respond/index.ts (Deno)
import { Anthropic } from "npm:@anthropic-ai/sdk@latest";

Deno.serve(async (req) => {
  const { userText } = await req.json();
  const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

  // 1) 모더레이션 분류
  const cls = await anthropic.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 8, temperature: 0,
    system: CLASSIFY_SYSTEM_PROMPT,
    messages: [{ role: "user", content: userText }],
  });
  const label = (cls.content[0] as any).text.trim();

  // 2) 식물 시점 응답
  const res = await anthropic.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 80, temperature: 0.85,
    system: PLANT_SYSTEM_PROMPT,
    messages: [{ role: "user", content: userText }],
  });
  const [empathy, plantVoice] = (res.content[0] as any).text.split("\n\n");

  return Response.json({
    empathy, plantVoice,
    isFlagged: label !== "SAFE",
    crisisLabel: label === "CRISIS",
  });
});
```

클라이언트는 이 함수만 호출 → API 키 노출 0.
