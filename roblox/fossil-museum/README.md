# 🦴 화석 박물관 (Fossil Museum) - 로블록스 게임

땅을 파서 공룡 화석 조각을 모으고, 다 모은 화석을 조립해서 **내 박물관**에 전시하는 게임이에요.
전시한 화석은 관람객 수입(코인)을 계속 벌어 주고, 다른 플레이어가 내 박물관에 **좋아요**를 누르면 수입이 더 늘어나요.

## 게임 흐름

1. **발굴장**에서 삽으로 흙더미를 파요. 클릭하거나 누르고 있으면 계속 파져요.
2. 흙더미가 부서지면 코인과 **화석 조각**이 나와요. 반짝이는 흙더미에서는 조각이 꼭 나오고, 희귀한 조각이 나올 확률도 높아요.
3. 한 종류의 조각(두개골, 척추, 다리 등)을 다 모으면 📖 **도감**에서 **조립**해요.
4. 조립한 화석은 내 박물관 전시대에 **3D 뼈대 모형**으로 자동 전시되고, 초당 코인을 벌어요.
5. 번 코인으로 🛒 **상점**에서 더 좋은 삽을 사고(파워, 속도, 행운이 올라가요), 전시대를 늘려요.
6. 8분마다 ☄️ **운석 낙하 이벤트**가 2분 동안 열려요. 운석을 파면 이벤트에서만 나오는 **우주 등급** 화석이 나와요.
7. 게임을 꺼도 박물관은 계속 벌어요. 다시 접속하면 최대 3시간 동안 번 수입의 50%를 받아요.

| 내용 | 수량 |
|---|---|
| 화석 종류 | 19종 (일반, 고급, 희귀, 영웅, 전설, 신화, 우주 7등급) |
| 발굴 도구 | 6개 (나무 삽부터 레이저 드릴까지) |
| 박물관 전시대 | 최대 16칸 |
| 수익화 | 게임 패스 3개, 개발자 상품 4개 |

## 바로 열어보기 (가장 쉬운 방법)

1. 이 폴더의 **`FossilMuseum.rbxlx`** 파일을 PC로 내려받아요. GitHub에서 파일을 연 뒤 "Download raw file" 버튼을 누르면 돼요.
2. 파일을 더블클릭하면 Roblox Studio에서 열려요.
3. 위쪽의 **▶ Play** 버튼을 눌러 테스트해요.

맵(발굴장, 박물관 8개, 길)은 게임이 시작될 때 스크립트가 자동으로 만들어요. 그래서 처음 열었을 때 화면이 비어 있는 게 정상이에요.

> **저장 기능 켜기**: Studio에서 테스트할 때 데이터를 저장하려면, 먼저 게임을 게시(File → Publish to Roblox)해야 해요.
> 그다음 Game Settings → Security → **Enable Studio Access to API Services**를 켜세요. 켜지 않으면 임시 데이터로 플레이돼요.

## Rojo로 작업하기 (코드를 계속 고칠 때 추천)

```bash
rokit install            # rojo, selene, stylua 설치 (rokit.toml)
rojo serve               # 그다음 Studio의 Rojo 플러그인에서 Connect
# 또는 파일로 만들기
rojo build -o FossilMuseum.rbxlx
```

Rojo가 없다면 `python3 tools/build_place.py`로도 `FossilMuseum.rbxlx`를 다시 만들 수 있어요.

## 파일 구조

```
src/
  shared/   (ReplicatedStorage.Shared - 서버와 클라이언트가 같이 씀)
    Config.luau        ← 가격, 확률, 수입, 화석 목록 같은 모든 숫자
    Economy.luau       ← 뽑기 확률, 수입 계산
    Util.luau          ← 숫자 표시 (1.2K, 3.4M)
  server/   (ServerScriptService.Server)
    Main.server.luau   ← 서버 시작점
    WorldBuilder.luau  ← 맵 자동 생성
    DataService.luau   ← 저장 / 불러오기 (DataStore)
    DigService.luau    ← 흙더미, 삽질, 보상, 운석 이벤트, 도구 지급
    MuseumService.luau ← 박물관 배정, 전시, 수입, 좋아요, 조립/판매
    FossilModel.luau   ← 3D 뼈대 모형 생성 (파트로 만들어서 에셋 필요 없음)
    ShopService.luau   ← 도구/전시대 구매, Robux 결제 처리
    Passes.luau        ← 게임 패스 확인
    Net.luau           ← 클라이언트 통신
  client/   (StarterPlayerScripts.Client)
    Main.client.luau   ← 클라이언트 시작점
    Hud.luau           ← 코인, 이벤트 배너, 메뉴 버튼, 알림
    Panels.luau        ← 도감 창, 상점 창
    Digger.luau        ← 삽질 입력 (PC 클릭, 모바일 터치)
    Effects.luau       ← 흙 튀기기, +코인 연출
```

## 게시 전에 꼭 할 일

1. **최대 인원 8명**: Game Settings → Places → Max Players를 8로 설정해요. 박물관 부지가 8개예요.
2. **게임 패스와 개발자 상품 만들기**: Creator Dashboard → 내 게임 → Monetization → Passes / Developer Products에서 만들어요.
   - 게임 패스: ⚡ 발굴 속도 2배, 🍀 행운 2배, 🏛️ 박물관 수입 2배
   - 개발자 상품: 코인 주머니, 코인 상자, 코인 금고, 행운 부스트 15분
   - 만든 ID를 `src/shared/Config.luau` 맨 위의 `id = 0` 자리에 넣어요. ID가 0이면 상점에 "준비 중"으로 표시돼요.
3. **썸네일과 아이콘**: 박물관에 전설 화석이 빛나는 장면을 캡처해서 쓰면 좋아요.

## 밸런스 조정

`Config.luau`의 숫자만 바꾸면 돼요.

| 바꾸고 싶은 것 | 고칠 항목 |
|---|---|
| 희귀한 화석이 나오는 확률 | `Rarities`의 `weight` |
| 화석 1개당 초당 수입 | `Rarities`의 `income` |
| 삽 가격과 성능 | `Tools` |
| 전시대 확장 가격 | `SlotPrices` |
| 운석 이벤트 간격과 지속시간 | `MeteorInterval`, `MeteorDuration` |

확률을 시뮬레이션해 보면 나무 삽으로 첫 화석을 완성하는 데 약 2~3분 걸려요. 처음에 빨리 재미를 느끼도록 맞춘 값이에요.

## 다음 업데이트 아이디어

- 🔁 **플레이어끼리 조각 거래**: 중복 조각에 가치가 생겨요.
- 🏆 **주간 박물관 랭킹**: 좋아요를 가장 많이 받은 박물관을 OrderedDataStore로 순위 매겨요.
- 🗺️ **새 발굴 지역**: 빙하 지대(매머드), 바닷가(해양 화석). 코인으로 지역을 열어요.
- 🎁 **매일 접속 보상**, 그룹 가입 보상
- 🔊 **효과음**: 삽질, 희귀 발견, 조립 소리. Creator Store의 무료 사운드를 쓰면 돼요.

## 참고

- 이 코드는 클라우드 환경에서 작성해서 **Studio에서 아직 실행해 보지 않았어요**. Play를 눌렀을 때 Output 창에 빨간 오류가 나오면 그 메시지를 그대로 알려주세요. 바로 고칠게요.
- 데이터 저장은 기본적인 재시도와 자동 저장(2분마다), 서버 종료 시 저장을 지원해요. 접속자가 많아지면 ProfileStore 같은 세션 잠금 방식으로 바꾸는 걸 추천해요.
