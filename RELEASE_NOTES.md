# 릴리스 노트 — 너의 정원 : 마음을 심는 감정 일기

새 빌드를 낼 때마다 이 파일 맨 위에 버전 블록을 추가하고, **아래 4곳에 같은 문구를 반영**한다.

1. **앱 내 "새로워진 점"** → `your_garden/lib/services/whats_new.dart` 의 `notes` 맵에 새 버전 키 추가
2. **pubspec 버전** → `your_garden/pubspec.yaml` 의 `version: X.Y.Z+build` 상향
3. **서버 버전 게이트** → Supabase `app_config` UPDATE (`latest_build`, 강제면 `min_supported_build`도)
   - 선택 권유: `update app_config set latest_build = <build>, latest_version = '<X.Y.Z>', updated_at = now() where id = 1;`
   - 강제: 위에 더해 `min_supported_build = <build>`, 필요 시 `update_message = '...'`
4. **Play Console** → 프로덕션 새 버전 → **"출시 노트"** 칸에 아래 `<ko-KR>` 블록 그대로 붙여넣기 (언어당 최대 500자)

---

## v1.0.2 (build 5) · 2026-07-10

### 📋 Play Console 출시 노트 (ko-KR) — 그대로 복붙

```
<ko-KR>
🌱 식물마다 이름을 지어줄 수 있어요
✍️ 오프라인에서도 마음이 사라지지 않고 임시 저장돼요
🔒 앱 잠금이 더 안전해졌어요 (잠금 화면·화면 캡처 보호)
🏷️ 마음 태그와 인사이트로 나를 돌아볼 수 있어요
🗑️ 설정에서 내 정원 데이터를 완전히 삭제할 수 있어요
🛡️ 개인정보 보호와 안정성을 개선했어요
</ko-KR>
```

### 앱 내 "새로워진 점" (whats_new.dart `'1.0.2'` 와 동일하게 유지)
- 🌱 식물마다 이름을 지어줄 수 있어요
- ✍️ 오프라인에서도 마음이 사라지지 않고 임시 저장돼요
- 🔒 앱 잠금이 더 안전해졌어요 — 잠금 화면·화면 캡처 보호
- 🏷️ 마음 태그와 인사이트로 나를 돌아볼 수 있어요
- 🗑️ 설정에서 내 정원 데이터를 완전히 삭제할 수 있어요
- 🛡️ 개인정보 보호와 안정성을 개선했어요

### 🛠 변경 요약 (개발용, 스토어 미노출)
- 개인정보 노출 제거·회사 계정(디케이컴퍼니) 통일, 문의 이메일 DKC260701@gmail.com
- 법무 페이지 이전(dkc260701) + Google Play 계정 삭제 URL 전용 페이지
- 버전 게이트: 강제/선택 업데이트 안내 (Supabase `app_config`, fail-open)
- 업데이트 후 "새로워진 점" 안내 + 설정에 앱 버전(빌드번호) 표시
- 서버 RLS 점검 통과(공개 노출 정책 제거, 5개 테이블 RLS ON)

---

<!-- 다음 버전 예시 (복사해서 위에 추가):

## v1.0.3 (build 6) · YYYY-MM-DD

### 📋 Play Console 출시 노트 (ko-KR)
```
<ko-KR>
· 새 기능 한 줄
· 개선 한 줄
</ko-KR>
```

### 앱 내 "새로워진 점"
- ...

### 🛠 변경 요약
- ...
-->
