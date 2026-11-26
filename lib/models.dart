// 테이블 정의서 v0.5와 같은 모양의 모델. 필드 이름은 컬럼 이름을 camelCase로 옮겼다.

enum Role { participant, organizer }

enum EventStatus {
  ready('READY', '미진행'),
  ongoing('ONGOING', '진행중'),
  ended('ENDED', '종료');

  const EventStatus(this.db, this.label);
  final String db;
  final String label;
}

enum Level {
  unknown('UNKNOWN', '미확인'),
  free('FREE', '여유'),
  normal('NORMAL', '보통'),
  busy('BUSY', '혼잡');

  const Level(this.db, this.label);
  final String db;
  final String label;
}

enum NotiType {
  eventUpdate('EVENT_UPDATE', '행사 변경'),
  parking('PARKING', '주차 상태'),
  crowd('CROWD', '현장 혼잡도');

  const NotiType(this.db, this.label);
  final String db;
  final String label;
}

enum VisitSource { qr, manual, other }

enum SocialProvider {
  naver('네이버'),
  kakao('카카오'),
  apple('애플'),
  google('구글');

  const SocialProvider(this.label);
  final String label;
}

/// participant / organizer 두 테이블을 한 클래스로 쓴다. 저장은 역할별 목록에 따로 한다.
/// address, bio, notify_*, push_token은 participant에만 있는 컬럼이다.
class Member {
  Member({
    required this.id,
    required this.role,
    this.loginId,
    this.passwordHash,
    required this.name,
    required this.email,
    this.address,
    this.profileImageUrl,
    this.bio,
    this.termsAgreedAt,
    this.notifyEnabled = true,
    this.notifySound,
    this.notifyPreview = true,
    this.notifyParking = true,
    this.notifyCrowd = true,
    this.pushToken,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  final int id;
  final Role role;
  String? loginId;
  String? passwordHash;
  String name;
  String email;
  String? address;
  String? profileImageUrl;
  String? bio;
  DateTime? termsAgreedAt;
  bool notifyEnabled;
  String? notifySound;
  bool notifyPreview;
  bool notifyParking;
  bool notifyCrowd;
  String? pushToken;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
}

class SocialAccount {
  SocialAccount(this.id, this.memberId, this.role, this.provider, this.providerUserId, {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  final int id;
  final int memberId;
  final Role role;
  final SocialProvider provider;
  final String providerUserId;
  final DateTime createdAt;
}

class Category {
  const Category(this.id, this.name);
  final int id;
  final String name;
}

class Event {
  Event({
    required this.id,
    required this.organizerId,
    required this.name,
    this.imageUrl = '',
    required this.description,
    this.visitInfo,
    this.program,
    this.status = EventStatus.ready,
    required this.startAt,
    required this.endAt,
    required this.region,
    required this.categoryId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    this.parkingLocation,
    this.parkingTotal,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  int id;
  final int organizerId;
  String name;
  String imageUrl;
  String description;
  String? visitInfo;
  String? program;
  EventStatus status;
  DateTime startAt;
  DateTime endAt;
  String region;
  int categoryId;
  String address;
  double latitude;
  double longitude;
  int capacity;
  String? parkingLocation;
  int? parkingTotal;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
}

class EventStatusSnapshot {
  EventStatusSnapshot(this.eventId);
  final int eventId;
  int? parkingCurrent;
  Level parkingLevel = Level.unknown;
  DateTime? parkingUpdatedAt;
  Level crowdLevel = Level.unknown;
  DateTime? crowdUpdatedAt;
}

class EventGuide {
  EventGuide({
    required this.id,
    required this.eventId,
    required this.guideName,
    required this.mapImageUrl,
    required this.program,
    required this.qrToken,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = DateTime.now();

  int id;
  int eventId;
  String guideName;
  String mapImageUrl;
  String program;
  final String qrToken;
  final DateTime createdAt;
  DateTime updatedAt;
}

class GuideSchedule {
  GuideSchedule(
      {this.id = 0, this.guideId = 0, required this.title, required this.startAt, required this.endAt, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now(),
        updatedAt = DateTime.now();

  int id;
  int guideId;
  String title;
  DateTime startAt;
  DateTime endAt;
  final DateTime createdAt;
  DateTime updatedAt;
}

class FavoriteEvent {
  FavoriteEvent(this.participantId, this.eventId, {DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  final int participantId;
  final int eventId;
  final DateTime createdAt;
}

class VisitRecord {
  VisitRecord(this.participantId, this.eventId, this.visitedAt, this.visitDate, this.source);
  final int participantId;
  final int eventId;
  final DateTime visitedAt;
  final DateTime visitDate; // 한국 시간 기준 날짜(시각 0시)
  final VisitSource source;
}

class AppNotification {
  AppNotification(this.id, this.participantId, this.eventId, this.type, this.content, this.createdAt);
  final int id;
  final int participantId;
  final int eventId;
  final NotiType type;
  final String content;
  DateTime? readAt;
  final DateTime createdAt;
}
