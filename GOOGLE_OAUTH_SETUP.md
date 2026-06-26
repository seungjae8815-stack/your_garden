# Google 로그인(백업) 설정 절차

앱 코드는 이미 적용됨. 아래 브라우저 설정만 하면 "Google로 백업/복구"가 동작한다.

## 고정값
- 콜백 URL(구글에 등록): `https://znjwnxqkdjwammcmytug.supabase.co/auth/v1/callback`
- 앱 리다이렉트(딥링크): `com.yourgarden.app://login-callback`
- 패키지명: `com.yourgarden.app`

---

## A. Google Cloud Console (console.cloud.google.com)
1. 프로젝트 생성/선택.
2. **APIs & Services → OAuth consent screen**
   - User type: **External** → 만들기
   - 앱 이름: `너의 정원`, 사용자 지원 이메일/개발자 이메일 입력
   - Scopes: `email`, `profile`, `openid` (기본)
   - **Test users**: 본인 Google 이메일 추가 (게시 전엔 테스트 사용자만 로그인 가능)
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application** (★중요 — Android 아님. Supabase가 웹 클라이언트로 처리)
   - Name: 아무거나 (예: `yourgarden-supabase`)
   - **Authorized redirect URIs**에 추가:
     `https://znjwnxqkdjwammcmytug.supabase.co/auth/v1/callback`
   - 만들기 → **Client ID**와 **Client secret** 복사

## B. Supabase 대시보드
1. **Authentication → Sign In / Up(Providers) → Google** → 켜기(Enable)
   - 위에서 복사한 **Client ID**, **Client Secret** 붙여넣기 → Save
2. **Authentication → URL Configuration → Redirect URLs**에 추가:
   `com.yourgarden.app://login-callback`
3. **Manual linking 허용** (linkIdentity에 필요)
   - Authentication 설정에서 "Allow manual linking"(수동 연결 허용) 토글 ON
   - (없거나 못 찾으면, "Google로 백업" 시 오류가 나는지 먼저 테스트 → 오류면 이 토글 때문)

## C. 테스트
1. 앱 → 설정 → **Google로 백업** → 브라우저 → (테스트 사용자) Google 계정 선택 →
   앱 복귀 → "Google 계정으로 백업됨 🌿"
2. 복구 확인: 전체 초기화(또는 재설치) → 설정 → **Google로 복구** → Google 로그인 →
   "복구됐어요" → 앱 재시작 → 정원 복원 확인

## 메모
- 게시(Publishing) 전 "테스트" 상태에선 "확인되지 않은 앱" 경고가 떠도 정상 (테스트 사용자는 진행 가능).
- Google 없이 쓰는 "복구 코드" 방식도 함께 제공됨 (migration 0006 적용 필요).
