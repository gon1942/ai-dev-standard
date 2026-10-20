# Framework Distribution

이 저장소는 공통 프레임워크를 개발·검증하는 **원본 저장소**다. 원본의 Product Spec,
Exec Plan, 원본 전용 회귀 테스트, 세션 캐시는 프레임워크 개발 이력이며 신규 프로젝트에
그대로 복제해서는 안 된다.

## 원본과 배포 템플릿의 경계

| 구분 | 원본 저장소 | 배포 템플릿 |
|---|---|---|
| 목적 | 프레임워크 기능 개발·회귀 검증·이력 보존 | 신규 프로젝트의 공통 개발 골격 |
| 검증 모드 | 이 저장소의 실제 회귀 구성을 반영한 `active` 가능 | 항상 `template`으로 시작 |
| Product Spec·Exec Plan | 프레임워크 개발 이력을 보존 | 인덱스·빈 기록 디렉터리만 포함 |
| 테스트 | `scripts/test-framework*.sh`를 포함 | 대상 프로젝트의 `scripts/test.sh`만 사용 |
| 생성 보고서·세션 캐시 | 로컬 재생성물 | 포함하지 않음 |
| OpenCode 의존성 | 로컬 설치물일 수 있음 | skill·agent 어댑터만 포함 |

따라서 이 원본 저장소를 GitHub의 `Use this template` 대상으로 직접 지정하지 않는다.
GitHub Template 저장소나 Release 아카이브는 아래 빌드 결과로 만든다.

## 배포 템플릿 만들기

출력 경로는 존재하지 않아야 한다. 스크립트는 기존 경로를 덮어쓰거나 삭제하지 않는다.

```bash
scripts/build-framework-template.sh --output /tmp/ai-dev-standard-template
```

빌드 결과에는 다음이 포함된다.

- 공통 정책·Skill Contract·온보딩 문서
- `AGENTS.md`, `CLAUDE.md`, OpenCode·Claude Code 어댑터
- `docs/framework-runtime-assets.tsv`에 선언된 대상 실행 자산
- `template` 모드의 `.ai-dev-standard.env`
- 신규 프로젝트용 README와 빈 공식 기록 디렉터리

다음은 의도적으로 포함하지 않는다.

- `docs/product-specs/`와 `docs/exec-plans/active/`의 원본 작업 이력
- `docs/generated/project-preflight.*`, `.ai-dev-standard/session-preflight.json`
- `.opencode/node_modules/`와 로컬 plugin package 파일
- `scripts/test-framework*.sh` 등 원본 전용 회귀 테스트

생성 직후에는 다음으로 골격을 확인한다.

```bash
/tmp/ai-dev-standard-template/scripts/check-framework.sh \
  --project-dir /tmp/ai-dev-standard-template
```

## GitHub Template과 향후 CLI

1. 검증된 빌드 출력물을 별도 `ai-dev-standard-template` 저장소 또는 Release 아카이브로 배포한다.
2. 신규 프로젝트 사용자는 GitHub의 `Use this template`으로 새 저장소를 만든다.
3. 기존 프로젝트용 `ai-dev-standard apply`와 신규 폴더용 `ai-dev-standard init` CLI는
   향후 **같은 배포 아티팩트**를 소비해야 한다. CLI가 원본 개발 저장소의 작업 이력을 직접
   복사해서는 안 된다.
4. Template 저장소에는 프레임워크 버전·변경 내역을 태그 또는 Release로 남기고, 프로젝트별
   업데이트는 diff·사람 승인 방식으로만 적용한다.

전역 Session Hook은 설치 편의 기능일 뿐이다. Hook이 존재하지 않아도 프로젝트 내부의
`AGENTS.md`, `docs/`, `scripts/`만으로 동일한 개발 절차를 수행할 수 있어야 한다.

## 원본 저장소 배포 전 점검

```bash
bash scripts/test-framework-template.sh
bash scripts/test-framework.sh
git status --short
```

`git status`에 세션 캐시·생성 보고서·OpenCode 의존성이 보이면 커밋하지 않는다. 원본의
활성 Exec Plan은 사람 리뷰·승인 전까지 삭제하지 않고 `active/`에 유지한다.
