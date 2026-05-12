// lib/core/services/service_events.dart
// Isolate ↔ UI 통신 이벤트 키 상수 모음.
// SyncService와 BackgroundServiceHandler 양쪽에서 import — 순환 의존 없음.

/// UI → Isolate: 새 TransmissionConfig 직렬화 맵 전달
const kEventUpdateConfig = 'update_config';

/// Isolate → UI: 패킷 flush 완료 알림 (패킷 데이터 포함)
const kEventPacketFlushed = 'packet_flushed';

/// Isolate → UI: 현재 sync 상태 요약
const kEventSyncStatus = 'sync_status';

/// UI → Isolate: 서비스 중단 요청
const kEventStopService = 'stop_service';
