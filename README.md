# Fest-On

지역 축제 통합 정보 서비스. 흩어져 있는 지역 축제 정보를 한곳에 모으고, 현장의 주차·혼잡도와 QR 가이드까지 이어 주는 Flutter 앱입니다.

- 참여자: 내 주변 축제를 찾고, 관심 행사로 저장하고, 현장 QR을 찍어 가이드와 방문 기록을 남깁니다.
- 개최자: 행사와 가이드를 등록하고, 주차 현황을 입력하고, 가이드마다 QR 코드를 만들어 현장에 배포합니다.

## 주요 기능

### 참여자

| 화면 | 기능 |
|---|---|
| 홈 | 상단바 지역(지역선택 → 세부선택)과 연결된 지역 필터, 최신순·관심순 정렬, 지역 인기 행사 배너 |
| 지도 | OpenStreetMap 위 행사 핀, 확대·축소·현위치 버튼, 고른 지역 기준 "내 주변" 거리순 목록 |
| 목록 | 검색, 지역·날짜·종류·정렬 필터, 별표로 관심 행사 등록 |
| 행사 상세 | 주차 현황(여유 %), 현장 혼잡도(여유/보통/혼잡/미확인), 방문 안내, 행사 가이드 확인 |
| QR | QR 스캔 → 하루 한 번 방문 기록 → 가이드 화면. 카메라가 없으면 QR 값 직접 입력 |
| 가이드 | 확대되는 행사장 지도, 진행 프로그램, 스케줄(진행 중 표시) |
| 마이 | 관심 행사, 방문 기록, 계정 설정(이름·이메일·자기소개·비밀번호), 알림 설정, 알림 목록 |

### 개최자

| 화면 | 기능 |
|---|---|
| 홈 | 내가 등록한 행사 배너와 목록 |
| 행사 | 등록된 행사 검색·필터, 행사 등록·수정·삭제, 주차 대수 입력 |
| 가이드 | 가이드 등록(행사장 지도, 프로그램, 일정 겹침 검사), QR 생성·공유 |
| 마이 | 등록된 행사·가이드, 계정 설정, 로그아웃 |

### 공통 규칙

- 로그인: 아이디 또는 이메일, 자동 로그인, 네이버·카카오·애플·구글 간편 로그인(시연용)
- 비밀번호: 영문+숫자 6~16자
- 현장 혼잡도: 최근 1시간 QR 방문 수 ÷ 수용 인원. 0.5 이하 여유, 0.7 이하 보통, 그 위 혼잡
- 주차 혼잡도: 현재 대수 ÷ 총 면수에 같은 기준
- 진행 중이 아니거나 값이 2시간보다 오래되면 "미확인"
- 관심 행사를 등록한 참여자에게만 알림(행사 변경, 주차 상태, 현장 혼잡). 알림 설정을 끈 사람은 제외하고, 같은 알림은 10분 안에 다시 보내지 않음
- 행사·가이드 수정과 주차 입력은 등록한 개최자 본인만 가능

## 시연 계정

| 역할 | 아이디 | 비밀번호 |
|---|---|---|
| 참여자 | `user1` (또는 `testuser@example.com`) | `pass1234` |
| 개최자 | `org1` | `pass1234` |
| 개최자 2 | `org2` (권한 확인용) | `pass1234` |

로그인 화면 위쪽에서 참여자/개최자를 먼저 고릅니다.

## 실행

Flutter 3.50 이상이 필요합니다. Flutter 3.50부터 Material 위젯은 `material_ui` 패키지에 있습니다.

```bash
flutter pub get
flutter run -d chrome     # 웹
flutter run               # 연결된 안드로이드 기기·에뮬레이터
flutter test              # 규칙 단위 시험
```

### 프로젝트 경로에 한글이 있을 때 (Windows)

안드로이드 빌드 도구는 경로에 한글이 있으면 실패합니다. 폴더를 옮기지 않으려면 가상 드라이브로 연결해서 빌드합니다.

```bat
subst X: "<프로젝트 폴더 경로>"
cd /d X:\
flutter build apk --debug
```

- `android/gradle.properties`에 `android.overridePathCheck=true`, `kotlin.incremental=false`가 들어 있습니다. 두 번째 줄은 프로젝트(X:)와 패키지 캐시(C:)의 드라이브가 달라 생기는 코틀린 캐시 오류를 막습니다.
- `subst` 연결은 재부팅하면 풀립니다.

### 로컬 서버로 실행

`server/`는 앱의 `lib/store.dart`를 그대로 불러 같은 규칙을 서버에서 돌리는 다트 서버입니다. 처음 켜면 앱의 시연 데이터(`lib/seed.dart`, 실제 축제 목록 `lib/real_events.dart` 포함)로 표를 채워 `server/data/db.json`에 남기고, 그 뒤로는 바뀐 값이 계속 남습니다. 여러 기기가 같은 서버에 붙으면 방문·혼잡도·알림을 함께 봅니다(5초마다 새 값을 받아 옴).

```bash
cd server
dart pub get
dart run bin/server.dart            # http://127.0.0.1:8080
dart test                           # 서버 시험
```

다른 창에서 앱을 서버 주소와 함께 실행합니다. `API_URL`을 빼면 예전처럼 서버 없이 앱 메모리에서 돕니다.

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8080
flutter run --dart-define=API_URL=http://10.0.2.2:8080        # 안드로이드 에뮬레이터 (10.0.2.2 = 이 컴퓨터)
flutter test test/server_e2e_test.dart --dart-define=API_URL=http://127.0.0.1:8080   # 켜 둔 서버와 연결 시험
```

#### dart·flutter 명령을 못 찾을 때 (Windows)

`dart`는 Flutter SDK의 `bin` 폴더에 함께 들어 있습니다. `'dart' 용어가 cmdlet ... 인식되지 않습니다`가 나오면 그 폴더를 사용자 PATH에 한 번 등록합니다.

```powershell
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";<Flutter SDK 경로>\bin", "User")
```

- 이미 열려 있던 터미널은 새 PATH를 모릅니다. VS Code·IntelliJ·Android Studio 안의 터미널은 프로그램을 완전히 껐다 켜야 반영됩니다(탭만 새로 열면 예전 PATH를 물려받음).
- 끄지 않고 지금 창에서 바로 쓰려면:
  ```powershell
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
  ```

#### 안드로이드 에뮬레이터(AVD)로 실행

웹과 같은 서버에 붙으므로 화면과 데이터가 같습니다(웹에서 바꾼 관심 행사·방문 기록이 AVD에서도 보임). 다른 점은 두 가지입니다.

1. 에뮬레이터 안의 `127.0.0.1`은 에뮬레이터 자신이라, 서버 주소를 `10.0.2.2`(= 이 컴퓨터)로 줍니다. 서버는 그대로 `127.0.0.1`로 켜 둡니다.
2. 프로젝트 경로에 한글이 있으면 안드로이드 빌드가 실패할 수 있어, 위의 `subst` 가상 드라이브로 실행합니다.

```powershell
subst X: "<프로젝트 폴더 경로>"
cd X:\
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

- 로그인할 때 "서버에 연결할 수 없습니다"가 나오면 서버가 켜져 있는지 먼저 봅니다. 서버가 켜져 있는데도 그렇다면 안드로이드가 `http` 주소를 막은 것일 수 있습니다. 그때는 `android/app/src/debug/AndroidManifest.xml`의 `<manifest>` 안에 `<application android:usesCleartextTraffic="true" />` 한 줄을 넣습니다(디버그 빌드에만 적용).

#### 그 밖에

- 같은 와이파이의 실제 폰에서 쓰려면 서버를 `dart run bin/server.dart --lan`으로 켜고, 앱은 `API_URL=http://<이 컴퓨터 IP>:8080`으로 실행합니다. 윈도우 방화벽이 8080 포트를 물어보면 허용합니다.
- 처음 데이터로 되돌리려면 서버를 끄고 `server/data` 폴더를 지운 뒤 다시 켭니다. 시연 데이터의 날짜는 처음 켠 날을 기준으로 정해집니다.
- 포트를 바꾸려면 `PORT` 환경 변수를 줍니다.
- 서버는 표를 메모리에 두고 바뀔 때마다 JSON 파일 하나로 통째로 저장합니다. 사용자가 많아지면 `db/schema.sql`의 PostgreSQL로 옮깁니다.

## 폴더 구조

| 경로 | 내용 |
|---|---|
| `lib/main.dart` | 앱 시작, 자동 로그인, 역할별 화면 분기 |
| `lib/models.dart` | 테이블 정의서의 12개 테이블과 같은 모양의 모델 |
| `lib/store.dart` | 데이터 저장소와 모든 규칙 (인증, 방문, 혼잡도, 알림, 권한, 일정 검사). 서버도 이 파일을 그대로 쓴다 |
| `lib/api.dart` | 화면이 저장소를 바꿀 때 부르는 곳. `API_URL`이 있으면 서버로 보낸다 |
| `lib/actions.dart` | 요청 이름 → 저장소 메서드 (서버와 앱이 같이 씀) |
| `lib/codec.dart` | 표 ↔ JSON (서버 저장과 전송) |
| `lib/seed.dart` | 시연용 샘플 데이터 (오늘 날짜 기준으로 진행중·예정·종료가 섞임) |
| `lib/widgets.dart` | 테마, 공통 위젯 |
| `lib/screens/auth.dart` | 로그인, 회원가입, 아이디·비밀번호 찾기 |
| `lib/screens/participant.dart` | 하단 탭, 홈, 지도, 목록, 행사 상세, 가이드, QR, 알림, 지역 선택 |
| `lib/screens/my.dart` | 마이, 관심 행사, 방문 기록, 계정 설정, 비밀번호 변경, 알림 설정 |
| `lib/screens/organizer.dart` | 개최자 탭, 행사 등록, 가이드 등록, QR 생성 |
| `server/` | 로컬 서버 (`bin/server.dart`), 서버 시험, Flutter 없이 돌리기 위한 대역 패키지(`flutter_stub`) |
| `db/schema.sql` | PostgreSQL 14 생성 SQL (테이블 12개, 제약·인덱스·트리거) |
| `test/store_test.dart` | 규칙 단위 시험 10개 |
| `assets/icons/` | 앱 아이콘, 로고, 소셜 로그인 버튼 |

## 데이터 구조

`db/schema.sql`은 테이블 정의서 v0.5를 따릅니다.

| 테이블 | 설명 |
|---|---|
| `participant`, `organizer` | 참여자·개최자 회원 (탈퇴는 `deleted_at` 표시) |
| `participant_social`, `organizer_social` | 소셜 로그인 연결 |
| `category` | 행사 종류 |
| `event` | 행사 정보 |
| `event_status_snapshot` | 행사별 현재 주차·혼잡도 (행사당 한 행) |
| `event_guide`, `guide_schedule` | 가이드와 일정, QR 값 |
| `favorite_event` | 관심 행사 |
| `visit_record` | QR 방문 기록 (참여자·행사·한국 날짜당 한 번) |
| `notification` | 알림 |

## 아직 시연용인 것

`API_URL` 없이 실행하면 서버 없이 앱 안 메모리에서 동작하고, 앱을 다시 켜면 샘플 상태로 돌아갑니다. 로컬 서버를 쓰면 값이 `server/data/db.json`에 남습니다.

- 소셜 로그인은 실제 OAuth 없이 시연용 계정으로 연결
- 아이디 찾기 SMS, 비밀번호 재설정 메일은 실제로 보내지 않음 (인증번호는 화면에 표시)
- 현위치는 GPS 대신 상단바에서 고른 지역의 대표 좌표
- 푸시 알림은 앱 안 알림 목록만 있음
- 올린 사진은 메모리에만 보관, 사진이 없으면 "사진" 자리표시
- 비밀번호 해시는 SHA-256 (로컬 서버도 같은 코드를 씀. 실제로 배포하면 서버에서 bcrypt/argon2로)
- 로컬 서버의 세션은 만료되지 않고 HTTP로 오감. 실제로 배포하면 만료 시각과 HTTPS를 둠
- 요청마다 서버가 표 전체(약 2MB)를 돌려줌. 같은 컴퓨터·와이파이에서는 문제없지만 사용자가 많아지면 바뀐 부분만 보내게 바꿈

## 지도

지도 타일은 [OpenStreetMap](https://www.openstreetmap.org/copyright)을 씁니다. 이용 조건에 따라 지도 오른쪽 아래에 출처를 표시합니다.
