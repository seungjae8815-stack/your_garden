# 나비·벌 생성 프롬프트 (Gemini 이미지) — 날갯짓 3프레임

정원을 날아다니는 나비/벌 애니메이션용 그림. 각 1마리를 **날개 위치 3프레임**(가로 스트립)
으로 생성한다. 앱이 프레임을 번갈아 그려 **펄럭임**을 만든다. (꽃/나무 프롬프트와 동일 형식)

## 앱 규격
- 프레임 **3개** → `butterfly_1.png`~`butterfly_3.png`, `bee_1.png`~`bee_3.png`
- 머리가 **오른쪽**을 향하게 (앱이 진행 방향에 따라 좌우 반전)
- 3프레임 모두 **같은 크기·같은 위치·같은 화풍**
- 순백(#FFFFFF) 배경 → 후처리로 투명 처리(슬라이싱+크롭+배경제거, 꽃에 쓴 파이프라인 재사용)

---

## 1. 나비 (Butterfly) 🦋

```
A single wide horizontal illustration of ONE cute butterfly shown in THREE wing
positions, arranged left to right in three equal-width panels, evenly spaced:
- Panel 1: wings fully open and flat (spread wide)
- Panel 2: wings raised to about a 45-degree angle
- Panel 3: wings nearly closed together, raised upright

The SAME butterfly in every panel — identical size, colors, and orientation,
seen from a top-down three-quarter view with its head pointing to the RIGHT.

Style: soft storybook watercolor illustration, gentle pastel colors, soft shading,
no harsh outlines. Pretty rounded wings in soft coral-pink and cream with delicate
darker patterns and tiny dots, slender body, two thin curved antennae.

Requirements:
- Pure flat WHITE background (#FFFFFF), no text, no labels, no cast shadow
- Each butterfly centered in its panel with a small margin
- Identical art style across all three frames
```

## 2. 벌 (Bee) 🐝

```
A single wide horizontal illustration of ONE cute round bumblebee shown in THREE
wing positions, arranged left to right in three equal-width panels, evenly spaced:
- Panel 1: wings raised up
- Panel 2: wings level (mid-flap)
- Panel 3: wings pushed down

The SAME bee in every panel — identical size, colors, and orientation, seen from a
side three-quarter view with its head pointing to the RIGHT.

Style: soft storybook watercolor illustration, gentle pastel colors, soft shading,
no harsh outlines. A plump fuzzy bee with classic golden-yellow and soft-black
stripes, tiny legs, big friendly eyes, and small translucent rounded wings.

Requirements:
- Pure flat WHITE background (#FFFFFF), no text, no labels, no cast shadow
- Each bee centered in its panel with a small margin
- Identical art style across all three frames
```

---

## 3. 반딧불 (Firefly) ✨ — 밤에만 등장

> 흰 배경에선 은은한 빛이 안 보이므로, 꼬리 끝을 **선명한 노랑-연두**로 그린다.
> 부드러운 빛 번짐(글로우)과 깜빡임은 앱에서 코드로 입힌다.

```
A single wide horizontal illustration of ONE cute firefly shown in THREE wing
positions, arranged left to right in three equal-width panels, evenly spaced:
- Panel 1: wings raised up
- Panel 2: wings level (mid-flap)
- Panel 3: wings lowered

The SAME firefly in every panel — identical size, colors, and orientation, seen
from a side three-quarter view with its head pointing to the RIGHT.

Style: soft storybook watercolor illustration, gentle colors, soft shading, no
harsh outlines. A small friendly beetle-like body in soft dark brown-charcoal with
tiny translucent rounded wings, and a plump rounded tail tip that is a BRIGHT
glowing yellow-green (luminous lime-yellow), clearly lit up. Cute and gentle.

Requirements:
- Pure flat WHITE background (#FFFFFF), no text, no labels, no cast shadow
- Each firefly centered in its panel with a small margin
- Identical art style across all three frames
- Keep the glowing tail a saturated yellow-green (not pale/white) so it stays
  visible after the background is removed
```

## 후처리
- 나비/벌/반딧불 각 1장(3프레임) 생성 → 슬라이싱/크롭/배경제거 →
  `butterfly_1..3.png`, `bee_1..3.png`, `firefly_1..3.png`로 저장.
- 그림이 없어도 앱은 임시 이모지(🦋🐝, 반딧불은 빛나는 점)로 동작. 그림 넣으면 자동 교체.
- 반딧불은 **밤에만** 나타나고, 앱이 꼬리 주변에 **노랑-연두 글로우 + 천천히 깜빡임**을 더한다.
