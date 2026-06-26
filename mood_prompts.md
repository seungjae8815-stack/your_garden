# 마음 날씨 아이콘 프롬프트 (Gemini 이미지) — 5단계

체크인의 "지금 마음 날씨는 어떤가요?" 5단계 아이콘. 꽃·곤충과 같은 **수채 동화풍**으로
통일해, 이모지 대신 우리 그림체로 보여준다. 한 장(가로 스트립 5칸)으로 생성 → 후처리로
`mood_1.png`~`mood_5.png` 저장. (그림 없으면 앱이 이모지로 폴백)

## 앱 규격
- 5칸 가로 스트립, **같은 크기·같은 화풍·같은 팔레트**
- 각 칸 가운데 정렬, 작은 여백
- 순백(#FFFFFF) 배경 → 후처리로 투명 처리 (꽃에 쓴 슬라이스+크롭+흰색키 파이프라인 재사용)
- 글자/라벨 없음, 그림자 없음

## 단계 (왼→오)
1. **많이 힘들어요** — 짙은 회색 비구름 + 빗방울 몇 개 (차분하게, 무섭지 않게)
2. **가라앉아요** — 부드러운 회색 흐린 구름 한 덩이
3. **그저 그래요** — 구름 사이로 해가 살짝 비치는 모습 (반쯤 흐림)
4. **괜찮아요** — 작은 구름 뒤로 환한 해 (대체로 맑음)
5. **좋아요** — 밝고 따뜻한 둥근 해 (작은 빛살)

## 프롬프트 (영문, 그대로 붙여넣기)

```
A single wide horizontal illustration showing FIVE weather icons in a row, arranged
left to right in five equal-width panels, evenly spaced. Each panel shows ONE simple
weather scene representing a mood, from gloomy to bright:
- Panel 1: a dark soft grey rain cloud with a few gentle raindrops (calm, not scary)
- Panel 2: a single soft grey overcast cloud, no rain
- Panel 3: a cloud with warm sunlight peeking out from behind it (partly cloudy)
- Panel 4: a bright sun mostly out, with one small soft cloud beside it
- Panel 5: a warm round glowing sun with a few short gentle sun rays

Style: soft storybook watercolor illustration, gentle pastel colors, soft shading,
rounded shapes, no harsh outlines. All five icons share the SAME art style, scale,
and color palette, like a cohesive set. Cozy and calming children's-book feel.

Requirements:
- Pure flat WHITE background (#FFFFFF), no text, no labels, no cast shadow
- Each icon centered in its panel with a small margin
- Identical art style across all five panels
```

## 후처리
- 생성한 1장(5칸)을 슬라이스/크롭/흰색배경 제거 → `mood_1.png`~`mood_5.png` 로
  `your_garden/assets/gardens/` 에 저장. (꽃·곤충과 동일 파이프라인)
- 앱은 `MoodIcon` 위젯이 자동으로 그림을 쓰고, 없으면 이모지(🌧️☁️⛅🌤️☀️)로 폴백.
