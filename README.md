# 크림슨 오스 (Crimson Oath)

캐릭터·몬스터 그림 및 직업별 스킬 효과 적용 내용과 미리보기: [아트 업데이트](docs/ART_UPDATE.md).

스킬 아이콘·고해상도 효과·폐성 안뜰 맵·체력바·스킬 슬롯 개선: [전투 화면 업데이트](docs/COMBAT_VISUAL_UPDATE.md).

바닥 대비·캐릭터 윤곽선·적 위험 표시 개선 및 전후 비교: [전투 가독성](docs/COMBAT_READABILITY.md).

다크 판타지 탑다운 액션 로그라이트입니다. 네 명의 영웅 중 한 명을 골라 공허의 군단이 쏟아내는 15개의 웨이브를 버티고, 5·10·15웨이브에 등장하는 보스(공포의 기사·핏빛 마녀·공허의 군주)를 쓰러뜨리면 승리합니다. 한 판은 약 13~15분입니다.

- 엔진: **Godot 4.3** (GDScript, Compatibility 렌더러 – 저사양 PC·스팀덱 대응)
- 언어: 한국어 / English (설정에서 변경)
- 입력: 키보드+마우스, 게임패드(자동 조준 지원)

기사의 3D 포즈 제작·스프라이트 마감과 실제 게임 영상: [기사 모션 업데이트](docs/KNIGHT_3D_UPDATE.md).

## 영웅

| 영웅 | 기본 공격 | 스킬 (우클릭) | 스킬 (Q) | 궁극기 (R) |
|---|---|---|---|---|
| 베스퍼 – 진홍의 그림자 (근접 암살자, 흡혈 4%) | 쌍단검 연격, 3타마다 2배 | 칼날 폭풍 – 사방으로 단검 투척 | 연막 – 3초 은신·이속 증가, 다음 3타 치명타 | 천 개의 칼날 – 적 12명 사이를 순간이동하며 베기 |
| 아스트라 – 별의 마법사 (원거리 광역, 별빛 보호막: 피해 흡수 후 6초간 안 맞으면 재생) | 추적 후 폭발하는 별의 구슬 | 별의 낙하 – 커서 위치에 유성 | 중력 우물 – 적을 끌어모으는 소용돌이 | 유성우 – 유성 14개 |
| 실바 – 깊은 숲의 사냥꾼 (원거리 관통) | 관통 화살 | 화살 세례 – 부채꼴 일제 사격 | 도약 사격 – 뒤로 도약, 속박 덫, 강한 화살 3발 | 화살비 – 4초간 지역 피해·둔화 |
| 레온 – 사자 기사 (근접 탱커, 방어력 20%) | 넓은 대검 베기, 강한 넉백 | 사자의 포효 – 주변 적 피해·기절 | 방패 돌격 – 돌진하며 밀쳐내고 기절 | 사자왕의 심판 – 거대한 검 + 6초 각성 |

궁극기는 처음에 절반 충전된 상태로 시작하고, 적을 처치할 때마다 빨리 충전됩니다.

적: 일반 몬스터 9종(구울, 박쥐, 해골 궁수, 거인, 사교도, 망령, 폭탄 시체, 방패병, 강령술사)과 모든 몬스터의 정예 버전, 보스 3종(5웨이브 공포의 기사, 10웨이브 핏빛 마녀, 15웨이브 공허의 군주). 자세한 내용은 [`docs/monsters.md`](docs/monsters.md) 와 게임 내 **몬스터 도감** 을 참고하세요.

무한 모드: 15웨이브를 클리어하면 승리 화면에서 **무한 모드로 계속** 할 수 있습니다. 웨이브가 끝없이 강해지고 5웨이브마다 보스가 등장하며, 최고 웨이브 기록이 갱신됩니다.

난이도: 영웅 선택 화면에서 **보통 / 어려움** 을 고를 수 있습니다. 어려움은 적 체력 ×1.4, 공격력 ×1.3, 등장량 ×1.25 이며 영웅별로 어려움 승리 기록이 따로 저장됩니다.

## 조작법

| 동작 | 키보드 & 마우스 | 게임패드 |
|---|---|---|
| 이동 | WASD / 방향키 | 왼쪽 스틱 |
| 조준 | 마우스 | 오른쪽 스틱 (입력 없으면 가장 가까운 적 자동 조준) |
| 공격 | 마우스 왼쪽(누르고 있기) / J | RT / X |
| 스킬 | 마우스 오른쪽 / K | LT |
| 두 번째 스킬 | Q / E | RB |
| 궁극기 | R | Y |
| 대시 (무적) | Space / Shift / L | A / LB |
| 일시정지 | Esc / P | Start |
| 전체 화면 | F11 | – |

## 실행 방법

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) 표준판(Standard, .NET 아님)을 받습니다.
2. Godot 프로젝트 관리자에서 **가져오기(Import)** → 이 폴더의 `project.godot` 선택.
3. **F5** 로 실행.

## 배포용 빌드 만들기 (스팀 업로드용)

1. Godot 에디터 메뉴 **에디터 → 내보내기 템플릿 관리** 에서 4.3 템플릿을 다운로드합니다.
2. **프로젝트 → 내보내기** 를 열면 `Windows Desktop`, `Linux`, `macOS` 프리셋이 이미 설정되어 있습니다.
3. 원하는 플랫폼을 선택하고 **프로젝트 내보내기** (디버그 체크 해제) → `build/` 폴더에 실행 파일이 생성됩니다.

명령줄로도 가능합니다:

```bash
godot --headless --export-release "Windows Desktop" build/windows/CrimsonOath.exe
godot --headless --export-release "Linux" build/linux/CrimsonOath.x86_64
```

`tests/`, `tools/` 폴더는 빌드에 포함되지 않습니다.

> **Windows 실행 파일 아이콘**: `.exe` 에 아이콘·버전 정보를 넣으려면 [rcedit](https://github.com/electron/rcedit/releases) 을 받아 **에디터 설정 → 내보내기 → Windows → rcedit** 경로를 지정하세요. 지정하지 않아도 게임은 정상 실행되며, 창 아이콘은 그대로 표시됩니다.

## 폴더 구조

```
assets/      초상화, 효과음·음악(WAV), 한글 폰트
scenes/      main.tscn (진입점)
scripts/
  autoload/  game.gd (설정·저장·번역·입력·테마), audio.gd (효과음·음악)
  data/      heroes.gd, upgrades.gd, strings.gd (한국어/영어 텍스트)
  game/      world.gd (웨이브·전투), player.gd, enemy.gd, hero_visual.gd ...
  ui/        메뉴, HUD, 레벨업, 일시정지, 설정, 결과 화면
tests/       autoplay – 봇이 영웅 4명으로 게임 전체를 플레이하는 자동 테스트
tools/       에셋 생성 스크립트 (초상화 배경 제거, 사운드 합성)
```

## 자동 테스트

봇이 실제로 게임을 끝까지 플레이하며 오류·진행 시간·받은 피해를 기록합니다. 보통 난이도에서 봇은 8판 중 7판을 클리어했습니다(판당 약 13~16분).

메뉴 흐름 테스트(설정·언어 전환·일시정지·레벨업·재시작·사망 후 영웅 변경 등 모든 버튼 경로):

```bash
godot --headless --fixed-fps 60 res://tests/ui_flow.tscn   # 마지막에 "UI FLOW OK" 출력
```

모든 화면 스크린샷(스토어 이미지용으로도 사용 가능):

```bash
godot --fixed-fps 60 --resolution 1920x1080 res://tests/screenshot.tscn -- ./screenshots
```

```bash
# 영웅 하나, 최대 25분 (게임 시간)
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- knight 25
# 영웅 4명 전부, 어려움 난이도
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- all 25 hard
```

## 텍스트·밸런스 수정

- 모든 문구: `scripts/data/strings.gd` (한국어 `ko`, 영어 `en`)
- 영웅 능력치: `scripts/data/heroes.gd`
- 적 능력치: `scripts/game/enemy.gd` 의 `KINDS`
- 웨이브 길이·적 등장 비율·보스 체력: `scripts/game/world.gd`
- 난이도 배율: `scripts/autoload/game.gd` 의 `DIFFICULTY`
- 레벨업 강화 목록: `scripts/data/upgrades.gd`

## 스팀 출시 전 체크리스트

- [ ] **일러스트 권리 확인** – `assets/portraits/` 의 영웅 그림(제공받은 원화에서 배경만 제거)과 `assets/bestiary/monster_sheet.png` 의 몬스터 도감 시트는 제공받은 이미지 그대로입니다. 도감 시트는 글자가 한국어로 그려져 있어 영어 설정에서도 한국어로 보입니다. 상업적 사용 권리가 있어야 하며, AI 생성 이미지라면 스팀 등록 시 *AI 생성 콘텐츠 공개* 항목에 기재해야 합니다.
- [ ] 스팀웍스 앱 ID 발급, 스토어 페이지(캡슐 이미지·스크린샷·트레일러) 준비
- [ ] (선택) 업적·클라우드 저장이 필요하면 [GodotSteam](https://godotsteam.com/) 연동
- [ ] Windows 빌드 코드 서명(선택), 회사명·저작권 문구 입력 (`export_presets.cfg`)
- [ ] 여러 PC/스팀덱에서 최종 플레이 테스트

## 라이선스 / 크레딧

- Godot Engine – MIT License
- Noto Sans KR – SIL Open Font License 1.1 (`assets/fonts/OFL.txt`)
- 음악·효과음 – `tools/gen_audio.py` 로 직접 합성 (외부 음원 없음)
