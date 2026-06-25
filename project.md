# 너의 정원 — 인수인계 마스터 (v2: 소셜 정원 MVP)

> 갱신: 2026-05-06 (v2 — 소셜 컨셉 확정)
> 모든 high-level 결정의 단일 source of truth. 새 결정이 확정되면 이 문서를 먼저 갱신하고 메모리 동기화.

---

## 프로젝트 개요

힘든 일이나 하소연을 텍스트로 적으면 그 글이 **양분**이 되어 식물을 키우는 힐링 모바일 게임. 개인의 마음 정리에 그치지 않고 **다른 사람의 정원에 들렀다 가는 행위 자체가 위로**가 되는 익명 커뮤니티.

**핵심 메타포 3중:**
1. **양분 변환** — 부정적 감정 → 식물의 양분 → 시각적 결과물
2. **Presence-based empathy** — 댓글 없음, 감정표현 5종만. 조언/판단 부담 없는 위로
3. **Trail of empathy** — 받은 반응 → 그 사람 정원 방문 → 자연스러운 감정 순환

**기존 SNS와의 결정적 차별:**
- 자유 텍스트 댓글 ❌ → 비교/조언/2차 가해 차단
- 알고리즘 피드 ❌ → 무작위 발견. 경쟁/노출 압박 없음
- 좋아요 카운트/팔로워 ❌ → 정량 지표 없음
- AI 응답이 메인 응답자 → 사람 사이의 직접 응답 부담 0

---

## 결정 사항 (2026-05-06 v2 확정)

### ① 앱 이름: **너의 정원** (yourgarden)
부제: "마음 한 줄, 자라는 정원"

### ② AI 응답 톤: **식물 시점 (양분/뿌리 메타포 중심)**
- 응답 형식: 공감 한 줄 + 식물 시점 한 줄
- 예: "오늘 마음이 무거우셨네요. / 당신이 묻은 마음이 제 뿌리에 닿았어요."
- 모델: `claude-haiku-4-5-20251001`

### ③ MVP 식물: **다육이 1종 (5단계)**
- 다른 식물(나무/벚꽃/분재/꽃)은 v2

### ④ 사용 흐름
- 입력 무제한, 식물 1일 1단계 성장 (5단계 ≈ 5일 cycle)
- 완성(stage 5) 후 "다음 식물 키우기" 버튼
- 잎 탭 → 그날 입력 + AI 응답 모달

### ⑤ UX wording 원칙
- "비우다/버리다/털다" ❌
- "묻다/스며들다/뿌리에 닿다/양분/심다" ✅
- 적용: 메인 CTA "마음 한 줄 묻기", 잎 카운트 "뿌리에 닿은 마음 N줄"

### ⑥ 공개 모델 — opt-in
- 첫 가입 시 "정원을 공개하시겠어요?" → 기본값 비공개
- 비공개 정원도 정상 작동 (AI 응답/식물 성장 동일)
- 공개 시에만 Discover 피드 노출
- 언제든 토글 가능

### ⑦ 신원 모델 — 익명 + 디바이스 바인딩
- 자동 생성 닉네임 (예: "햇살이 머무는 다육이 #4821")
- 디바이스 ID 기반 (UUID, OS keystore 보관)
- 로그인/이메일 ❌
- 디바이스 잃으면 데이터 손실 risk → v2에서 클라우드 백업

### ⑧ 감정표현 — 5종, 잎(entry) 단위
타인 정원의 잎 1개에 1개 반응 가능. 받는 식물에 누적 시각 효과:
- 💧 **물방울** — 눈물 공감
- ☀️ **햇살** — 응원
- 🍃 **바람** — 위로
- 🌑 **그늘** — 조용한 곁
- 🌱 **새싹** — 희망
각 반응은 받는 정원에 작은 입자/이펙트로 머묾 (시간 흘러도 사라지지 않음, 누적).

### ⑨ Discover 발견 — 무작위
- "오늘 만나볼 정원" 5개 무작위 카드
- 알고리즘 추천 ❌, 시간순 ❌, 인기순 ❌
- 공개 + 자해/혐오 flag 없는 정원에서만 추첨

### ⑩ 호혜성 — 자연스러운 동선만
- 보내야 받는 강제 ❌
- "받은 반응" 알림에 그 사람 정원으로 가는 버튼 → 자연스럽게 호혜 형성

### ⑪ 모더레이션
- Claude API로 입력 시점 hard-flag (자해/혐오/욕설)
- flag 시: 본인 정원 저장 ✅, Discover 노출 ❌, 사용자에게는 silent (낙인 방지)
- 자해/위기 키워드: 1577-0199(자살예방), 1393(보건복지부) 안내 모달
- 사용자 신고 → admin 검토 큐로

### ⑫ 백엔드: **Supabase**
- Postgres + Realtime + Anonymous Auth + Storage
- Region: Seoul (ap-northeast-2)
- 무료 tier 한도: 500MB DB, 50k MAU — MVP 충분

### ⑬ 로컬 캐시
- Hive로 본인 정원 데이터 미러링 → 오프라인에서도 본인 식물/잎 열람 가능
- 입력은 온라인 시점에만 가능 (AI 호출 필요)

---

## MVP 핵심 루프

```
[나의 정원]            [다른 정원]              [받은 반응]
  ↓ 마음 묻기            ↓ Discover 진입           ↓ 알림 탭
  ↓ AI 응답              ↓ 잎 탭 → 본문 읽기       ↓ 그 사람 정원으로
  ↓ 잎 +1                ↓ 감정표현 1개 남기기      ↓ 감정표현 남기기
  → 식물 1일 1단계 성장    → 그 사람의 잎에 누적     → 다시 그가 나에게 ...
```

---

## MVP 8 화면

| # | 화면 | 핵심 |
|---|---|---|
| 1 | **Onboarding** | 자동 닉네임 + 공개 여부 + 약관 |
| 2 | **Home — 나의 정원** | 다육이 + 잎 + "마음 묻기" + 받은 반응 배지 |
| 3 | **Input — 마음 묻기** | 텍스트 입력 (~500자) |
| 4 | **AI 응답 모달** | 식물 시점 2줄 |
| 5 | **Leaf Detail (본인)** | 그날 입력 + AI 응답 |
| 6 | **Discover** | 랜덤 5개 정원 카드 |
| 7 | **Other's Plant** | 타인 정원 + 잎 탭 → 본문 + 감정표현 5종 |
| 8 | **Notifications** | 받은 반응 + 그 사람 정원 이동 |

자세한 화면 설계는 `specs.md` §2 참조.

---

## 데이터 모델 (Supabase Postgres)

```
profiles  (id, device_id unique, nickname, is_public, created_at)
plants    (id, owner_id → profiles, species, current_stage, started_at,
           last_growth_at, is_completed)
entries   (id, plant_id → plants, user_text, ai_empathy, ai_plant_voice,
           stage_when_added, is_flagged, created_at)
reactions (id, from_profile_id → profiles, to_entry_id → entries,
           reaction_type ∈ {water,sun,wind,shade,sprout}, created_at)
visits    (id, visitor_id → profiles, visited_plant_id → plants, created_at)
```

세부 컬럼 타입/RLS는 `specs.md` §1.5-1.6.

---

## 6주 로드맵 (v2 — 소셜 MVP)

| 주 | 기간 | 내용 |
|---|---|---|
| **W1** | 5/6~5/12 | 마스터 문서 v2 + Figma 8화면 + Supabase 프로젝트/스키마 + RLS. Flutter 학습 병행. |
| **W2** | 5/13~5/19 | Flutter 혼자 정원 완성 (입력→AI→식물 성장 + Hive 캐시) + supabase_flutter 통합 + 익명 auth |
| **W3** | 5/20~5/26 | Discover 피드 + Other's Plant + 감정표현 5종 (시각 효과 포함) |
| **W4** | 5/27~6/2 | Notifications + 방문 trail + 모더레이션(Claude hard-flag) + 자해 안내 모달 |
| **W5** | 6/3~6/9 | 신고/차단 기능 + PP/약관 + Google Play 등급 + 베타 5-10명 |
| **W6** | 6/10~6/16 | Google Play 출시. 본인이 시드 데이터 며칠치 입력 (콜드 스타트 대응). |

**위험 요소:** 첫 Flutter + 첫 백엔드. W3-4가 최대 고비. 막히면 베타를 W5 후반으로 미루고 출시 1주 미루는 안전 밸브 둠.

---

## 출시 전 필수 체크리스트 (Google Play 통과용)

- [ ] **신고 기능** — 각 잎/정원에 신고 버튼
- [ ] **차단 기능** — 특정 정원 숨김
- [ ] **개인정보처리방침 (PP)** — 디바이스 ID 수집 명시 (한국 개인정보보호법)
- [ ] **이용약관** — 콘텐츠 책임/모더레이션 권한
- [ ] **콘텐츠 등급** — 사용자 생성 콘텐츠 + 상호작용 → 청소년 보호 정책 적용
- [ ] **자해/위기 안내 모달** — 1577-0199, 1393
- [ ] **개발자 계정 ($25)**

---

## 사용자 모으기 전략

### 출시 전부터 시작
1. **빌드인 퍼블릭** — 인스타/스레드에 개발 과정 매일 공유
2. **TikTok/Shorts** (이미 운영 중인 강점 활용)
   - "고민 적으면 다육이 자라는 앱 만드는 중"
   - 소셜 기능 추가될 때 "혼자 정원 → 함께 정원" 업데이트 자체가 콘텐츠
3. **커뮤니티 시드** — 디시 인디게임 갤러리, 레딧 r/IndieDev

### 출시 직전~직후
- 앱 이름 검색 노출
- 스크린샷 5장 (다운로드율 결정)
- 설명문 첫 두 줄에 핵심 가치 + 감정 키워드
- **콜드 스타트:** 베타 5-10명 + 본인이 며칠치 시드 콘텐츠 입력 → 첫 사용자가 빈 피드를 보지 않도록
- 첫 100명 사용자 직접 메시지 피드백

---

## 수익 모델

- 출시 후 6개월: 광고 0, 100% 무료 (사용자 모집 집중)
- 6개월 후: 보상형 광고 1개 + 월 2,900~4,900원 구독
- 1년 후: 1년치 성장 책자 PDF/인쇄본 ← Postgres SQL 쿼리 효율적
- **광고 의존은 비추** (힐링 정서와 충돌)

---

## 이번 주(W1) 즉시 할 일

### Day 1-2 (5/6~5/7) — 환경 + 기획 ✅ 일부 완료
- ✅ Flutter 3.41.9 + Dart 3.11.5 (`C:\src\flutter`)
- ✅ Android Studio + SDK 36.1.0 + 라이선스
- ✅ JDK 17 + JAVA_HOME 등록
- ✅ Flutter 카운터 데모 → Home 화면 프로토타입
- ✅ 양분 메타포 wording 전환
- ✅ v2 소셜 컨셉 확정 + 마스터 문서 v2 갱신 (이 문서)

### Day 3-5 (5/8~5/12) — Figma + Supabase + Flutter 학습
- 🔲 **Supabase 무료 계정 + 프로젝트 (Seoul region)** — 사용자가 브라우저로
- 🔲 Postgres 스키마 + RLS 마이그레이션 작성 (`specs.md` §1.5-1.6 보고)
- 🔲 Figma 프로젝트 + 8화면 와이어프레임 (Onboarding/Discover/Other's Plant/Notifications 신규)
- 🔲 Flutter codelab "Write your first Flutter app" (2-3시간)
- 🔲 오준석 Flutter 기초 1-3편 (Widget/setState/Navigator)

---

## 환경 (5/6 기준)

- 노트북: Lenovo IdeaPad 5 15ITL05 (i5-11세대, 16GB, MX450, 256GB SSD)
- OS: Windows 11 Pro
- Flutter 3.41.9 / Dart 3.11.5 (`C:\src\flutter`)
- Android Studio 2025.3.4.7 + SDK 36.1.0
- OpenJDK 17 (`JAVA_HOME` 등록)
- VS Code (winget) + Claude Code
- 폰(`R3CX5075YNT`) USB 디버그 인증 미완 (블로커 아님 — Chrome web으로 충분)
- Visual Studio 미설치 (Win 데스크톱 빌드 불필요 → 무시)
