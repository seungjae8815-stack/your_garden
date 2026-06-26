# 꽃 생성 프롬프트 (Gemini 이미지) — 5종 × 5단계

너의 정원 앱에 넣을 꽃 일러스트를 **Gemini 2.5 Flash Image(별칭 Nano Banana)** 로
생성하기 위한 프롬프트 모음. 각 종마다 새싹→만개의 **5단계 성장 스트립 1장**을 생성한다.

## 왜 영어인가
이미지 모델은 학습 캡션 대부분이 영어라, **식물학적 용어**(feathery foliage, ray
petals, trumpet corona 등)와 **스타일 지시**가 영어일 때 훨씬 정확히 반영된다.
"고증에 맞는 꽃잎·줄기·새싹"이 목표이므로 프롬프트는 영어로 작성한다.

## 앱 기술 규격 (반드시 반영)
- 단계 **5개**: `1 새싹 · 2 어린잎 · 3 성장기 · 4 만개 직전(봉오리) · 5 만개`
  → 파일명 `<species>_1.png` ~ `<species>_5.png`
- 앱이 **화분(`pot.png`)을 따로 합성** → 그림엔 **화분·땅 그리지 말 것**, 식물만
- `BoxFit.contain` + **하단중앙 정렬**, 단계별로 키가 커짐 → 식물 밑동이 **프레임 맨
  아래 중앙**에서 위로 자라야 함
- 배경은 최종적으로 **투명 PNG** 필요. 제미나이는 투명 출력이 불안정하니 **순백
  (#FFFFFF)** 으로 뽑고 후처리로 배경 제거 + 5칸 슬라이싱 + 내용 크롭

## 사용법
1. 종별 프롬프트를 그대로 붙여넣어 1장씩 생성. 마음에 들 때까지 재생성.
2. 첫 종 결과가 좋으면 그 이미지를 **레퍼런스로 첨부**하고 "same art style"이라고
   지시 → 5종 화풍 통일.
3. 5장(각 5칸 스트립) → 슬라이싱/크롭/배경제거 → `tulip_1.png` 식으로 저장.
4. 앱 `PlantSprite`/species 목록에 종별 에셋 연동 (별도 코드 작업).

---

## 1. 코스모스 (Cosmos) 🌸

```
A single wide horizontal illustration showing the FIVE growth stages of ONE pink
cosmos (Cosmos bipinnatus) plant, arranged left to right in a row, in five
equal-width panels, evenly spaced.

Style: soft storybook watercolor illustration, gentle pastel colors, cozy
cottage-garden picture-book look, soft shading, no harsh outlines. Identical art
style, line weight, and color across all five stages.

The SAME plant growing — identical, botanically accurate cosmos foliage and
flowers throughout, only the growth changes:
- Stage 1: a tiny sprout, just two small narrow seed-leaves (cotyledons) poking up
- Stage 2: a slender green stem with the first FEATHERY, thread-like, finely
  divided fern-dill-like cosmos leaves; no flower yet
- Stage 3: a taller, airy, wispy stem with abundant feathery foliage and one
  closed pointed bud (with a star-shaped green calyx) on top
- Stage 4: the same plant with ONE fully open pink cosmos flower — a single daisy-
  like bloom with 8 broad petals that have notched/toothed tips and a yellow
  center disk
- Stage 5: a lush, bushy, branching plant with several pink cosmos flowers in full
  bloom, all with the same 8 notched petals and yellow centers

Requirements:
- All five plants grow straight up from the SAME ground baseline, rooted at the
  bottom, bottom-aligned; each later stage clearly taller than the previous
- NO flower pot, NO container, NO soil mound — just the plant itself
- Pure flat WHITE background (#FFFFFF), no ground shadows, no props, no text,
  no labels, no numbers
- Each plant centered in its panel, full plant visible with a small top margin
```

---

## 2. 튤립 (Tulip) 🌷

```
A single wide horizontal illustration showing the FIVE growth stages of ONE coral-
pink tulip (Tulipa) plant, arranged left to right in a row, in five equal-width
panels, evenly spaced.

Style: soft storybook watercolor illustration, gentle pastel colors, cozy
cottage-garden picture-book look, soft shading, no harsh outlines. Identical art
style, line weight, and color across all five stages.

The SAME plant growing — identical, botanically accurate tulip leaves and flower
throughout, only the growth changes:
- Stage 1: a single pointed shoot of tightly rolled leaves pushing up from a bulb,
  deep green with a faint reddish tip (NO seed-leaves — it is a bulb plant)
- Stage 2: two or three broad, strap-shaped, slightly bluish-green waxy leaves
  unfurling; no flower yet
- Stage 3: leaves fully spread with one smooth, sturdy, upright stem rising from
  the center, topped by a small closed green bud
- Stage 4: the same plant, the egg-shaped bud now swollen and showing coral-pink
  color at its tip, the cup still closed
- Stage 5: one single classic cup / goblet-shaped tulip flower fully open at the
  top of the stem, with 6 smooth glossy tepals, coral-pink

Requirements:
- All five plants grow straight up from the SAME ground baseline, rooted at the
  bottom, bottom-aligned; each later stage clearly taller than the previous
- NO flower pot, NO container, NO soil mound — just the plant itself
- Pure flat WHITE background (#FFFFFF), no ground shadows, no props, no text,
  no labels, no numbers
- Each plant centered in its panel, full plant visible with a small top margin
```

---

## 3. 해바라기 (Sunflower) 🌻

```
A single wide horizontal illustration showing the FIVE growth stages of ONE
sunflower (Helianthus annuus) plant, arranged left to right in a row, in five
equal-width panels, evenly spaced.

Style: soft storybook watercolor illustration, gentle pastel colors, cozy
cottage-garden picture-book look, soft shading, no harsh outlines. Identical art
style, line weight, and color across all five stages.

The SAME plant growing — identical, botanically accurate sunflower foliage and
flower throughout, only the growth changes:
- Stage 1: a tiny sprout with two rounded oval seed-leaves (cotyledons) on a short
  stem, fresh light green
- Stage 2: the first pair of true leaves appears — heart-shaped, with toothed
  edges, rough and slightly hairy; the stem starts to thicken; no flower yet
- Stage 3: a tall, thick, hairy stem with several large alternating heart-shaped
  leaves; still no flower
- Stage 4: a round green flower bud (wrapped in green bracts) at the top of the
  stem, just starting to show yellow at its edges
- Stage 5: one large composite sunflower head fully open — a ring of bright yellow
  ray petals around a big brown-golden central disk of seeds, the head slightly
  nodding

Requirements:
- All five plants grow straight up from the SAME ground baseline, rooted at the
  bottom, bottom-aligned; each later stage clearly taller than the previous
- NO flower pot, NO container, NO soil mound — just the plant itself
- Pure flat WHITE background (#FFFFFF), no ground shadows, no props, no text,
  no labels, no numbers
- Each plant centered in its panel, full plant visible with a small top margin
```

---

## 4. 장미 (Rose) 🌹

```
A single wide horizontal illustration showing the FIVE growth stages of ONE rose-
red rose (Rosa) plant, arranged left to right in a row, in five equal-width
panels, evenly spaced.

Style: soft storybook watercolor illustration, gentle pastel colors, cozy
cottage-garden picture-book look, soft shading, no harsh outlines. Identical art
style, line weight, and color across all five stages.

The SAME plant growing — identical, botanically accurate rose foliage and flower
throughout, only the growth changes:
- Stage 1: a small sprout with two little rounded seed-leaves (cotyledons) on a
  reddish young stem
- Stage 2: the first odd-pinnate compound leaves appear — 3 to 5 oval leaflets
  with serrated edges; the stem still young and reddish; no flower yet
- Stage 3: a stronger green woody stem with small thorns (prickles) and several
  serrated compound leaves
- Stage 4: a teardrop-shaped bud, the green sepals curling back to reveal spiral-
  furled red petal color at the tip
- Stage 5: one classic rose flower fully open — many layered, spiraled, gently
  ruffled petals forming a rounded cupped bloom in deep rose-red, on a thorny
  leafy stem

Requirements:
- All five plants grow straight up from the SAME ground baseline, rooted at the
  bottom, bottom-aligned; each later stage clearly taller than the previous
- NO flower pot, NO container, NO soil mound — just the plant itself
- Pure flat WHITE background (#FFFFFF), no ground shadows, no props, no text,
  no labels, no numbers
- Each plant centered in its panel, full plant visible with a small top margin
```

---

## 5. 수선화 (Daffodil / Narcissus) 🌼

```
A single wide horizontal illustration showing the FIVE growth stages of ONE
daffodil (Narcissus) plant, arranged left to right in a row, in five equal-width
panels, evenly spaced.

Style: soft storybook watercolor illustration, gentle pastel colors, cozy
cottage-garden picture-book look, soft shading, no harsh outlines. Identical art
style, line weight, and color across all five stages.

The SAME plant growing — identical, botanically accurate daffodil leaves and
flower throughout, only the growth changes:
- Stage 1: a few slender pointed green shoots emerging from a bulb, grass-blade-
  like with rounded tips (NO seed-leaves — it is a bulb plant)
- Stage 2: several long, flat, strap-shaped (linear) bluish-green leaves standing
  upright; no flower yet
- Stage 3: a leafless round flower stalk (scape) rising among the leaves, tipped
  with a closed papery sheath (spathe)
- Stage 4: the bud emerging sideways from the spathe, swelling, pale, nodding
  slightly downward
- Stage 5: one iconic daffodil flower fully open — 6 flat white tepals surrounding
  a contrasting deep-yellow trumpet-shaped central corona, the flower facing
  forward and slightly downward

Requirements:
- All five plants grow straight up from the SAME ground baseline, rooted at the
  bottom, bottom-aligned; each later stage clearly taller than the previous
- NO flower pot, NO container, NO soil mound — just the plant itself
- Pure flat WHITE background (#FFFFFF), no ground shadows, no props, no text,
  no labels, no numbers
- Each plant centered in its panel, full plant visible with a small top margin
```

---

## 단계 매핑 메모
프롬프트의 5단계는 앱 단계 의미(`4=만개 직전 / 5=만개`)와 자연스럽게 대응되도록
구성했다(4단계=봉오리/색 비침, 5단계=완전 개화). 단, 코스모스는 4단계를 "한 송이
개화", 5단계를 "여러 송이 풍성"으로 잡았다(원래 시도한 버전 유지). 엄격히 통일하려면
4단계를 봉오리 상태로 바꾸면 된다.

## 종 → 앱 species 네이밍(예정)
| 종 | 한글 | 에셋 prefix |
|----|------|-------------|
| Cosmos | 코스모스 | `cosmos_1..5.png` |
| Tulip | 튤립 | `tulip_1..5.png` |
| Sunflower | 해바라기 | `sunflower_1..5.png` |
| Rose | 장미 | `rose_1..5.png` |
| Narcissus | 수선화 | `daffodil_1..5.png` |
