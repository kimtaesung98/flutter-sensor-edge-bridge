# Flutter Sensor Edge Bridge

> **Wear OS → Phone → Edge** 구간의 센서 데이터를 자율적으로 수집·버퍼링·전송하는 Flutter 릴레이 앱.  
> Android 포그라운드 서비스(Isolate) 기반으로 백그라운드에서 동작하며, 관리자 전용 모니터링 UI를 제공합니다.

---

## 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [폴더 구조](#폴더-구조)
3. [데이터 흐름 (DFD)](#데이터-흐름-dfd)
   - [Level 0 — 컨텍스트](#level-0--컨텍스트)
   - [Level 1 — 주요 프로세스](#level-1--주요-프로세스)
   - [Level 2 — 상세 흐름](#level-2--상세-흐름)
4. [모듈별 설명](#모듈별-설명)
   - [main.dart](#maindart)
   - [core/network](#corenetwork)
   - [core/services](#coreservices)
   - [data/repositories](#datarepositories)
   - [domain](#domain)
   - [dependency_injection](#dependency_injection)
   - [presentation](#presentation)
5. [전송 채널 비교](#전송-채널-비교)
6. [설정 & 환경](#설정--환경)

---

## 아키텍처 개요

본 프로젝트는 **Clean Architecture** 를 기반으로 3개 계층으로 분리됩니다.

```
┌─────────────────────────────────────────────────┐
│              Presentation (UI)                  │
│   AppRouter / AuthGate / AdminMonitor / Settings│
├─────────────────────────────────────────────────┤
│              Core (Services)                    │
│   BackgroundServiceHandler / SyncService        │
│   ConnectivityOrchestrator / WifiStatusService  │
│   BluetoothScanService                          │
├─────────────────────────────────────────────────┤
│              Domain (Entities & Interfaces)     │
│   SensorPacket / TransmissionConfig             │
│   IEdgeTransport / ISensorBufferRepository      │
├─────────────────────────────────────────────────┤
│              Data (Implementations)             │
│   HttpEdgeTransport / BluetoothEdgeTransport    │
│   WiredEdgeTransport / SensorBufferRepository   │
└─────────────────────────────────────────────────┘
```

> **의존 방향**: Presentation → Core → Domain ← Data  
> Domain은 어떤 외부 패키지도 import하지 않습니다.

---

## 폴더 구조

```
flutter-sensor-edge-bridge/
│
├── lib/
│   ├── main.dart                          # 앱 진입점
│   │
│   ├── core/
│   │   ├── network/
│   │   │   ├── connectivity_orchestrator.dart   # 이중 링크 모니터 + 자동 sync 제어
│   │   │   └── wifi_status_service.dart         # Wi-Fi SSID / IP 실시간 감지
│   │   │
│   │   └── services/
│   │       ├── background_service_handler.dart  # Android Foreground Isolate 엔진
│   │       ├── bluetooth_scan_service.dart      # BLE 장치 스캔 및 페어링
│   │       ├── service_events.dart              # Isolate ↔ UI 이벤트 키 상수
│   │       └── sync_service.dart                # 포그라운드 sync 컨트롤러
│   │
│   ├── data/
│   │   └── repositories/
│   │       ├── bluetooth_edge_transport.dart    # BLE GATT 전송 구현
│   │       ├── http_edge_transport.dart         # Wi-Fi HTTP 전송 구현
│   │       ├── sensor_buffer_repository.dart    # SQLite 버퍼 구현
│   │       └── wired_edge_transport.dart        # Ethernet/USB 전송 구현
│   │
│   ├── domain/
│   │   ├── entities/
│   │   │   └── sensor_packet.dart               # 센서 데이터 도메인 엔티티
│   │   ├── models/
│   │   │   ├── transmission_config.dart         # 전송 정책 설정 모델
│   │   │   └── transport_type.dart              # 전송 채널 열거형
│   │   └── repositories/
│   │       ├── i_edge_transport.dart            # 전송 채널 추상 인터페이스
│   │       └── i_sensor_buffer_repository.dart  # 버퍼 저장소 추상 인터페이스
│   │
│   ├── dependency_injection/
│   │   └── locator.dart                         # GetIt DI 등록 및 팩토리
│   │
│   └── presentation/
│       ├── app_router.dart                      # 3-화면 라우터 (AnimatedSwitcher)
│       └── screens/
│           ├── admin_monitor_screen.dart        # 실시간 패킷 모니터링 대시보드
│           ├── auth_gate_screen.dart            # 관리자 로그인 게이트
│           └── settings_screen.dart             # 전송 정책 / 장치 설정 화면
│
├── android/                                     # Android 네이티브 (포그라운드 서비스)
├── ios/                                         # iOS 네이티브
├── pubspec.yaml                                 # 의존성 선언
└── analysis_options.yaml                        # Lint 규칙
```

---

## 데이터 흐름 (DFD)

### Level 0 — 컨텍스트

시스템 전체를 하나의 프로세스로 추상화한 컨텍스트 다이어그램입니다.

```
                      가속도계 데이터
  ┌─────────────┐   (BLE / WearOS)    ┌──────────────────────┐
  │  Wear OS    │──────────────────▶  │                      │
  │  Device     │                     │   Sensor Edge Bridge │
  └─────────────┘                     │       (Flutter App)  │
                                      │                      │──────▶ Edge Server
  ┌─────────────┐   관리자 인증 / 설정 │                      │       /ingest
  │  Admin User │──────────────────▶  │                      │
  └─────────────┘                     └──────────────────────┘
                                              │  │
                                         모니터링 UI / 상태 피드백
```

---

### Level 1 — 주요 프로세스

앱 내부를 5개의 주요 프로세스로 분해한 DFD입니다.

```
                       ┌─────────────────────────────────────────────────────────┐
                       │                    Flutter App                          │
                       │                                                         │
  Wear OS              │  ┌─────────────┐    SensorPacket    ┌────────────────┐  │
  (BLE 가속도계) ──────▶│  │  P1. 데이터  │──────────────────▶│  D1. SQLite    │  │
                       │  │  수집 엔진   │                    │  (sensor_      │  │
                       │  │ (Background  │◀──────────────────│  bridge.db)    │  │
                       │  │  Isolate)   │  pending packets   └────────────────┘  │
                       │  └──────┬──────┘                                        │
                       │         │ kEventPacketFlushed                           │
                       │         ▼                                               │
                       │  ┌─────────────┐                    ┌────────────────┐  │
                       │  │  P2. 동기화  │   TransmissionConfig│  D2. Shared   │  │
                       │  │  서비스      │◀──────────────────│  Preferences   │  │
                       │  │ (SyncService)│                    └────────────────┘  │
                       │  └──────┬──────┘                                        │
                       │         │ packets batch                                 │
                       │         ▼                                               │
                       │  ┌─────────────┐   HTTP/BLE/Wired                      │
                       │  │  P3. 전송    │─────────────────────────────────────▶ Edge
                       │  │  채널 선택   │◀─────────────────────────────────────  Server
                       │  │ (Transport) │   ACK (acked IDs)                     │
                       │  └─────────────┘                                        │
                       │                                                         │
                       │  ┌─────────────┐   LinkState streams                   │
                       │  │  P4. 연결    │─────────────────────────────────────▶ │
                       │  │  감시        │◀─────────────────────────────────────  │
                       │  │ (Orchestrator│  Wear Link / Edge Link               │
                       │  └──────┬──────┘                                        │
                       │         │ startSync / stopSync                         │
                       │         ▼                                               │
                       │  ┌─────────────┐   DualLinkStatus / packetStream       │
  Admin User ─────────▶│  │  P5. 관리자  │─────────────────────────────────────▶ Admin
                       │  │  UI          │                                       │ Monitor
                       │  └─────────────┘                                        │
                       └─────────────────────────────────────────────────────────┘
```

---

### Level 2 — 상세 흐름

실제 코드 흐름을 타임라인 순서로 나타낸 시퀀스 다이어그램입니다.

#### 앱 시작 시퀀스

```
main()
  │
  ├─▶ initializeBackgroundService()      # Foreground Isolate 등록
  │       └── AndroidConfiguration 설정 (채널 ID, 알림 제목)
  │
  ├─▶ setupLocator()                     # DI 컨테이너 초기화
  │       ├── SharedPreferences 로드
  │       ├── SensorBufferRepository     (SQLite)
  │       ├── IEdgeTransport             (config에 따라 HTTP/BLE/Wired 선택)
  │       ├── SyncService
  │       ├── ConnectivityOrchestrator
  │       │       ├── WearLinkMonitor    (4초 주기 폴링)
  │       │       └── EdgeLinkMonitor    (6초 주기 ping)
  │       ├── WifiStatusService
  │       └── BluetoothScanService
  │
  ├─▶ SettingsPersistence.load*()        # 설정값 / 관리자 자격증명 로드
  │
  └─▶ runApp(SensorBridgeApp)
          └── AppRouter → AuthGateScreen
```

#### 센서 데이터 수집 → 전송 시퀀스

```
ConnectivityOrchestrator
  │
  ├── WearLinkMonitor.stateStream ──▶ LinkState.connected
  └── EdgeLinkMonitor.stateStream ──▶ LinkState.connected
           │  (양쪽 모두 connected)
           ▼
  SyncService.startSync()
           │
           ▼
  FlutterBackgroundService.startService()
           │
           ▼  [Background Isolate 진입점: onStart()]
           │
  ┌────── Timer.periodic(intervalMs) ──────────────────────┐
  │                                                         │
  │  1. 센서 읽기 (현재: 시뮬레이션, 추후 BLE/WearOS 대체)   │
  │       └── SensorPacket { id, timestamp, ax, ay, az }   │
  │                                                         │
  │  2. Write-ahead: SQLite INSERT                          │
  │       └── packets 테이블 (transmitted = 0)              │
  │                                                         │
  │  3. 미전송 패킷 최대 200개 조회                           │
  │       └── SELECT WHERE transmitted = 0                  │
  │                                                         │
  │  4. HTTP POST {edgeUrl}/ingest                          │
  │       ├── 성공(200): acked IDs 반환                      │
  │       │       └── UPDATE transmitted = 1                │
  │       │       └── DELETE transmitted = 1 (pruning)      │
  │       └── 실패: 버퍼 유지, 다음 주기에 재시도              │
  │                                                         │
  │  5. service.invoke(kEventPacketFlushed, {...})           │
  │       └── Isolate → UI 채널                              │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
           │  kEventPacketFlushed 이벤트
           ▼
  SyncService._listenToIsolate()
           │
           ├── SensorPacket 역직렬화
           └── _packetCtrl.add(packet)   ──▶  AdminMonitorScreen
```

#### 설정 변경 핫스왑 시퀀스

```
SettingsScreen (UI)
  │
  ├─▶ SyncService.updateConfig(newConfig)
  │       └── _bgService.invoke(kEventUpdateConfig, config.toMap())
  │                                │
  │                                ▼  [Background Isolate]
  │                          service.on(kEventUpdateConfig)
  │                                └── config = TransmissionConfig.fromMap(data)
  │                                └── startFlushTimer()   # 즉시 새 주기로 재시작
  │
  └─▶ SettingsPersistence.saveConfig(newConfig)  # 재시작 시에도 유지
```

#### 연결 단절 → 버퍼링 → 재연결 흐름

```
EdgeLinkMonitor
  │  ping() 실패 (edgeUrl 응답 없음)
  │
  └──▶ LinkState.disconnected
              │
              ▼
  ConnectivityOrchestrator._update()
              │  prev.allConnected=true → new.allConnected=false
              ▼
  SyncService.stopSync()
              │
              └──▶ _bgService.invoke(kEventStopService)
                          │
                          ▼  [Background Isolate]
                    flushTimer.cancel()
                    service.stopSelf()

  ※ 이 사이에도 SQLite 버퍼는 transmitted=0 상태로 유지됨

  Edge 서버 복구 후:
  EdgeLinkMonitor.ping() 성공 ──▶ LinkState.connected
              │
              ▼
  SyncService.startSync()   # 서비스 재시작
              └──▶ 버퍼에 쌓인 패킷 일괄 flush
```

---

## 모듈별 설명

### `main.dart`

| 역할 | 내용 |
|------|------|
| 초기화 순서 | Background Service → DI Locator → 설정 로드 → runApp |
| UI 테마 | Material 3 다크 테마 (`#0A0E1A` 배경, `#00B4FF` primary) |
| 화면 방향 | 세로 고정 (portraitUp / portraitDown) |

---

### `core/network`

#### `connectivity_orchestrator.dart`

두 링크(Wear→Phone, Phone→Edge)를 동시에 감시하고, 양쪽이 모두 connected일 때만 sync를 자동 시작/정지합니다.

```
WearLinkMonitor  ──stateStream──▶ ┐
                                   ├──▶ ConnectivityOrchestrator ──▶ SyncServiceController
EdgeLinkMonitor  ──stateStream──▶ ┘         (startSync / stopSync)
```

| 클래스 | 역할 |
|--------|------|
| `WearLinkMonitor` | 4초 주기로 Wear OS 연결 상태 폴링 (현재 stub, MethodChannel 교체 예정) |
| `EdgeLinkMonitor` | 6초 주기로 `IEdgeTransport.ping()` 호출 |
| `ConnectivityOrchestrator` | 두 링크 상태를 `DualLinkStatus`로 합산, sync 자동 제어 |
| `NoOpSyncController` | 테스트용 더미 구현 |

#### `wifi_status_service.dart`

`connectivity_plus` + `network_info_plus`로 Wi-Fi SSID / IP를 실시간 감지합니다.  
Android 8+ 환경에서는 위치 권한이 있어야 SSID를 읽을 수 있습니다.

---

### `core/services`

#### `background_service_handler.dart`

Android 포그라운드 서비스로 동작하는 **별도 Isolate**입니다.

- 메인 Isolate와 메모리를 공유하지 않으므로 SQLite/HTTP 의존성을 독자적으로 초기화합니다.
- `Timer.periodic`으로 센서를 읽고, SQLite에 write-ahead 후 HTTP POST를 시도합니다.
- `service.invoke()` 채널을 통해 UI에 패킷 이벤트를 전달합니다.

```
이벤트 방향         키 상수              페이로드
UI → Isolate   kEventUpdateConfig   TransmissionConfig 직렬화 맵
UI → Isolate   kEventStopService    (없음)
Isolate → UI   kEventPacketFlushed  { id, timestamp, ax, ay, az, bufferCount, sent }
```

#### `sync_service.dart`

포그라운드 측 sync 컨트롤러. `SyncServiceController` 추상을 구현합니다.

- `startSync()` → Background Isolate 시작 + config 전달
- `stopSync()` → Isolate에 정지 신호
- `updateConfig()` → 런타임 설정 핫스왑 (Isolate 재시작 없이 즉시 반영)
- `packetStream` → `AdminMonitorScreen`에 실시간 패킷 피드 제공

#### `bluetooth_scan_service.dart`

BLE 장치 스캔, 연결, 권한 관리를 담당합니다.

| 메서드 | 설명 |
|--------|------|
| `startScan()` | BLE 스캔 시작 (timeout 후 자동 정지) |
| `stopScan()` | 스캔 중단 |
| `connectById()` | 특정 장치에 GATT 연결 |
| `isConnected()` | 현재 연결 여부 확인 |
| `devicesStream` | 발견된 장치 목록 스트림 |
| `adapterStateStream` | BT 어댑터 상태 스트림 |

#### `service_events.dart`

Isolate ↔ UI 통신 키 상수만 정의하는 순수 상수 파일. 순환 의존 없음.

---

### `data/repositories`

모든 구현체는 `domain/repositories` 의 추상 인터페이스를 구현합니다.

#### `http_edge_transport.dart` — `IEdgeTransport`

```
POST {edgeBaseUrl}/ingest   { "packets": [...] }
                ◀──────────  { "acked": ["id1","id2",...] }

HEAD {edgeBaseUrl}/health   → 200 미만이면 connected
```

- 타임아웃 5초 (ping은 3초)
- 비-200 응답 시 빈 acked 반환 → 패킷은 버퍼에 유지

#### `bluetooth_edge_transport.dart` — `IEdgeTransport`

```
BLE GATT 서비스: 0000ffe0-...
TX 특성:         0000ffe1-...

패킷 → JSON 직렬화 → UTF-8 인코딩 → 512바이트 청크 분할 → GATT Write
```

- MTU 안전 한도 512바이트씩 분할 전송
- 쓰기 성공 = 모두 ACK 처리 (BLE는 point-to-point)
- 연결 실패 시 다음 시도에 자동 재연결

#### `wired_edge_transport.dart` — `IEdgeTransport`

```
connectivity_plus 가 ethernet 감지 시에만 HTTP 전송
(USB 테더링 / 실제 이더넷 어댑터 모두 포함)
```

#### `sensor_buffer_repository.dart` — `ISensorBufferRepository`

```
SQLite 테이블: packets
  id          TEXT PRIMARY KEY
  timestamp   INTEGER (millisecondsSinceEpoch)
  ax, ay, az  REAL (m/s²)
  transmitted INTEGER (0=pending, 1=sent)

인덱스: idx_transmitted (transmitted)
```

| 메서드 | SQL |
|--------|-----|
| `save()` | INSERT OR REPLACE |
| `getPending()` | SELECT WHERE transmitted=0 LIMIT 200 |
| `markTransmitted()` | UPDATE SET transmitted=1 WHERE id IN (...) |
| `pruneTransmitted()` | DELETE WHERE transmitted=1 |
| `pendingCount()` | COUNT WHERE transmitted=0 |

---

### `domain`

외부 패키지를 import하지 않는 순수 Dart 계층입니다.

#### `entities/sensor_packet.dart`

```dart
SensorPacket {
  id:          String          // UUID v4
  timestamp:   DateTime
  ax, ay, az:  double          // 가속도 m/s²
  transmitted: bool            // false = 버퍼 대기 중
}
```

#### `models/transmission_config.dart`

| 필드 | 타입 | 기본값 |
|------|------|--------|
| `speed` | `TransmissionSpeed` | `realTime` (100ms) |
| `wifiOnly` | `bool` | `false` |
| `transportType` | `TransportType` | `wifi` |
| `edgeServerUrl` | `String` | `http://192.168.1.100:8080` |
| `wearDeviceId/Name` | `String?` | null |
| `edgeDeviceId/Name` | `String?` | null |

#### `models/transport_type.dart`

| 열거값 | storageKey | 설명 |
|--------|-----------|------|
| `wifi` | `"wifi"` | HTTP over Wi-Fi |
| `bluetooth` | `"bluetooth"` | BLE GATT |
| `wired` | `"wired"` | HTTP over Ethernet/USB |

---

### `dependency_injection`

#### `locator.dart`

GetIt 싱글턴 등록 순서:

```
1. SharedPreferences         (await)
2. TransmissionConfig        (from prefs)
3. ISensorBufferRepository   → SensorBufferRepository
4. IEdgeTransport            → _buildTransport(config) 팩토리 선택
5. SyncService               (buffer + transport + bgService 주입)
6. ConnectivityOrchestrator  (WearLinkMonitor + EdgeLinkMonitor + SyncService)
7. WifiStatusService
8. BluetoothScanService
```

`_buildTransport()` 팩토리:

```
TransportType.wifi        → HttpEdgeTransport(edgeBaseUrl)
TransportType.bluetooth   → BluetoothEdgeTransport(edgeDeviceId)
TransportType.wired       → WiredEdgeTransport(edgeBaseUrl)
```

---

### `presentation`

#### `app_router.dart`

`AnimatedSwitcher` 기반 3-화면 라우터입니다.

```
_Screen.gate     → AuthGateScreen      (로그인)
_Screen.admin    → AdminMonitorScreen  (모니터링)
_Screen.settings → SettingsScreen      (설정)
```

설정 화면은 진입 origin(_Screen)을 기억해 뒤로가기 시 정확한 화면으로 복귀합니다.

#### `auth_gate_screen.dart`

관리자 ID / 패스워드 입력 게이트. 인증 성공 시 AdminMonitorScreen으로 전환합니다.

#### `admin_monitor_screen.dart`

`SyncService.packetStream`을 구독해 실시간으로 패킷 데이터를 표시합니다.

- DualLinkStatus (Wear / Edge 연결 상태 표시기)
- 수신 패킷 카운터 / 버퍼 잔량
- ax/ay/az 값 시계열 표시
- 설정 화면 진입 버튼

#### `settings_screen.dart`

| 설정 항목 | 저장 위치 | 효과 |
|-----------|-----------|------|
| 전송 속도 (RT/1s/3s/5s) | SharedPreferences | Isolate에 핫스왑 즉시 반영 |
| 전송 채널 (WiFi/BLE/Wired) | SharedPreferences | 다음 앱 시작 시 적용 |
| Edge 서버 URL | SharedPreferences | Isolate 설정 업데이트 |
| Wear OS 장치 BLE 페어링 | SharedPreferences | BLE 스캔 → 장치 선택 |
| Edge 장치 BLE 페어링 | SharedPreferences | BluetoothEdgeTransport에 적용 |
| 관리자 ID / 패스워드 변경 | SharedPreferences | 즉시 반영 |

---

## 전송 채널 비교

```
┌────────────────┬──────────────┬──────────────┬──────────────────┐
│ 채널            │ 프로토콜      │ 감지 방법     │ 특징              │
├────────────────┼──────────────┼──────────────┼──────────────────┤
│ Wi-Fi (기본)   │ HTTP POST    │ HEAD /health │ 범용, 추가 설정 없음│
│ Bluetooth BLE  │ GATT Write   │ 연결 장치 확인 │ 512B 청크 분할    │
│ Wired          │ HTTP POST    │ ethernet 감지 │ USB/실제 이더넷   │
└────────────────┴──────────────┴──────────────┴──────────────────┘
```

모든 채널은 `IEdgeTransport` 인터페이스로 추상화되어 있으므로,  
새로운 전송 채널(MQTT, gRPC 등)을 추가할 때는 구현체만 추가하면 됩니다.

---

## 설정 & 환경

### 필수 의존성

| 패키지 | 용도 |
|--------|------|
| `flutter_background_service` | Android Foreground Service / Isolate |
| `get_it` | 의존성 주입 (Service Locator) |
| `sqflite` | 로컬 SQLite 버퍼 |
| `shared_preferences` | 설정값 영속화 |
| `http` | Wi-Fi / Wired HTTP 전송 |
| `connectivity_plus` | Wi-Fi / Ethernet 감지 |
| `network_info_plus` | SSID / IP 조회 |
| `flutter_blue_plus` | BLE 스캔 및 GATT 통신 |
| `permission_handler` | Android 런타임 권한 |

### Android 권한 (AndroidManifest.xml 필요)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### 기본 설정값

| 설정 | 기본값 |
|------|--------|
| Edge 서버 URL | `http://192.168.1.100:8080` |
| 전송 속도 | Real-time (100ms) |
| 전송 채널 | Wi-Fi |
| 버퍼 최대 조회 | 200 packets/flush |
| Flush 최소 간격 | 100ms (CPU 과부하 방지) |
| Edge ping 주기 | 6초 |
| Wear 연결 감지 주기 | 4초 |
