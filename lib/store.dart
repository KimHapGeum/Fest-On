import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'models.dart';
import 'seed.dart';

/// 앱의 데이터와 규칙을 한곳에 둔다.
/// shortcut: 데이터는 메모리에만 있어 앱을 끄면 처음 상태로 돌아간다. 서버를 붙일 때 이 클래스의 메서드를 API 호출로 바꾼다.
class AppStore extends ChangeNotifier {
  AppStore({DateTime Function()? clock, bool seed = true}) : now = clock ?? DateTime.now {
    if (seed) seedStore(this);
  }

  final DateTime Function() now;

  // ---- 테이블 ----
  final participants = <Member>[];
  final organizers = <Member>[];
  final socials = <SocialAccount>[];
  final categories = <Category>[];
  final events = <Event>[];
  final snapshots = <int, EventStatusSnapshot>{};
  final guides = <EventGuide>[];
  final schedules = <GuideSchedule>[];
  final favorites = <FavoriteEvent>[];
  final visits = <VisitRecord>[];
  final notifications = <AppNotification>[];

  /// 고른 사진. 키는 'local:N' 형태의 image_url 값.
  /// shortcut: 서버가 없어서 사진을 메모리에 둔다. 서버를 붙이면 올린 뒤 받은 주소를 image_url에 넣는다.
  final localImages = <String, Uint8List>{};

  int _seq = 100;
  int nextId() => ++_seq;

  Member? me;

  // ---- 상수 ----
  static const crowdWindow = Duration(minutes: 60); // 알고리즘 9-1의 "최근 N분"
  static const staleAfter = Duration(hours: 2); // 이보다 오래된 현황 값은 미확인으로 보여 준다
  static const notiDedupe = Duration(minutes: 10); // 같은 종류 알림을 다시 보내지 않는 시간
  static const regions = ['서울', '경기', '인천', '강원', '충청', '전라', '경상', '부산', '제주'];

  static final _pwRule = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)\S{6,16}$');
  static final _emailRule = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? checkPassword(String pw) => _pwRule.hasMatch(pw) ? null : '비밀번호는 영문+숫자 6~16자로 입력해주세요';
  /// 010은 11자리, 예전 번호(011·016~019)는 10~11자리. 하이픈·공백은 무시한다.
  static bool isPhone(String s) => RegExp(r'^(010\d{8}|01[16-9]\d{7,8})$').hasMatch(s.replaceAll(RegExp(r'[-\s]'), ''));
  static String? checkEmail(String email) =>
      _emailRule.hasMatch(email.trim()) ? null : '올바른 이메일 주소 형식으로 입력해 주세요';

  // shortcut: 해시는 서버가 해야 한다. 서버를 붙이면 bcrypt/argon2로 서버에서 만들고 앱은 비밀번호를 그대로 보내지 않게 TLS로만 보낸다.
  static String hash(String pw) => sha256.convert(utf8.encode('fest-on:$pw')).toString();

  List<Member> _table(Role r) => r == Role.participant ? participants : organizers;

  void touch() => notifyListeners();

  // ============ 계정·인증 ============

  String? signup({
    required Role role,
    required String loginId,
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required bool termsAgreed,
  }) {
    loginId = loginId.trim();
    email = email.trim();
    if (loginId.isEmpty || name.trim().isEmpty) return '아이디와 이름을 입력해 주세요';
    final e = checkEmail(email) ?? checkPassword(password);
    if (e != null) return e;
    if (password != passwordConfirm) return '비밀번호가 일치하지 않습니다';
    if (!termsAgreed) return '필수 약관에 모두 동의해주세요';
    final live = _table(role).where((m) => m.deletedAt == null);
    if (live.any((m) => m.loginId == loginId)) return '이미 사용 중인 아이디입니다';
    if (live.any((m) => m.email.toLowerCase() == email.toLowerCase())) return '이미 가입된 이메일입니다';
    _table(role).add(Member(
      id: nextId(),
      role: role,
      loginId: loginId,
      passwordHash: hash(password),
      name: name.trim(),
      email: email,
      termsAgreedAt: now(),
    ));
    notifyListeners();
    return null;
  }

  /// 아이디 또는 이메일로 로그인. 실패 문구는 계정 존재 여부를 드러내지 않게 하나로 쓴다.
  String? login(Role role, String idOrEmail, String password) {
    final key = idOrEmail.trim().toLowerCase();
    final h = hash(password);
    final m = _table(role).where((m) =>
        m.deletedAt == null &&
        m.passwordHash == h &&
        (m.loginId?.toLowerCase() == key || m.email.toLowerCase() == key));
    if (m.isEmpty) return '아이디 또는 비밀번호가 일치하지 않습니다';
    me = m.first;
    notifyListeners();
    return null;
  }

  /// shortcut: 진짜 OAuth 없이 제공자별 가짜 회원 번호로 연결한다. 키를 받으면 각 SDK가 준 provider_user_id를 넘기게 바꾼다.
  void socialLogin(Role role, SocialProvider p, {String? providerUserId}) {
    final uid = providerUserId ?? 'demo-${p.name}-${role.name}';
    final link = socials.where((s) => s.role == role && s.provider == p && s.providerUserId == uid);
    Member? m;
    if (link.isNotEmpty) {
      m = _table(role).where((x) => x.id == link.first.memberId && x.deletedAt == null).firstOrNull;
    }
    if (m == null) {
      m = Member(
        id: nextId(),
        role: role,
        name: '${p.label} 사용자',
        email: '$uid@${p.name}.social',
        termsAgreedAt: now(), // 첫 로그인을 약관 동의로 본다
      );
      _table(role).add(m);
      socials.removeWhere((s) => s.role == role && s.provider == p && s.providerUserId == uid);
      socials.add(SocialAccount(nextId(), m.id, role, p, uid));
    }
    me = m;
    notifyListeners();
  }

  Member? findMember(Role role, int id) => _table(role).where((m) => m.id == id && m.deletedAt == null).firstOrNull;

  void logout() {
    me = null;
    notifyListeners();
  }

  /// 탈퇴는 삭제 표시만 한다. 방문 기록은 남긴다.
  void withdraw() {
    final m = me;
    if (m == null) return;
    m.deletedAt = now();
    socials.removeWhere((s) => s.role == m.role && s.memberId == m.id);
    if (m.role == Role.participant) favorites.removeWhere((f) => f.participantId == m.id);
    me = null;
    notifyListeners();
  }

  /// 이름으로 가입 아이디를 찾아 가린 값으로 돌려준다.
  /// shortcut: 정의서에 전화번호 컬럼이 없어 이름만 맞춰 본다. 본인인증 서비스를 붙이면 인증 결과의 이름·번호로 찾는다.
  List<String> findLoginIds(String name) => [
        ...participants,
        ...organizers,
      ].where((m) => m.deletedAt == null && m.name == name.trim()).map((m) => _mask(m.loginId ?? m.email)).toList();

  static String _mask(String s) {
    final at = s.indexOf('@');
    final head = at < 0 ? s : s.substring(0, at);
    final keep = head.length <= 3 ? 1 : 3;
    return head.substring(0, keep) + '*' * (head.length - keep) + (at < 0 ? '' : s.substring(at));
  }

  String? changePassword(String current, String next, String confirm) {
    final m = me;
    if (m == null) return '로그인이 필요합니다';
    if (m.passwordHash == null) return '소셜 로그인 계정은 비밀번호가 없습니다';
    if (m.passwordHash != hash(current)) return '현재 비밀번호가 일치하지 않습니다';
    final e = checkPassword(next);
    if (e != null) return e;
    if (next != confirm) return '새 비밀번호가 일치하지 않습니다';
    if (next == current) return '기존 비밀번호와 동일한 비밀번호로는 변경할 수 없습니다';
    m.passwordHash = hash(next);
    m.updatedAt = now();
    notifyListeners();
    return null;
  }

  String? updateProfile({String? name, String? email, String? bio}) {
    final m = me!;
    if (name != null) {
      if (name.trim().isEmpty) return '이름을 입력해 주세요';
      m.name = name.trim();
    }
    if (email != null) {
      final e = checkEmail(email);
      if (e != null) return e;
      final taken = _table(m.role)
          .any((x) => x.id != m.id && x.deletedAt == null && x.email.toLowerCase() == email.trim().toLowerCase());
      if (taken) return '이미 가입된 이메일입니다';
      m.email = email.trim();
    }
    if (bio != null) m.bio = bio.trim().isEmpty ? null : bio.trim();
    m.updatedAt = now();
    notifyListeners();
    return null;
  }

  // ============ 행사 조회 ============

  Iterable<Event> get liveEvents => events.where((e) => e.deletedAt == null);
  Event? event(int id) => liveEvents.where((e) => e.id == id).firstOrNull;
  Category? category(int id) => categories.where((c) => c.id == id).firstOrNull;

  /// 저장된 진행 현황. 종료 일시가 지났으면 종료로 본다.
  EventStatus statusOf(Event e) => now().isAfter(e.endAt) ? EventStatus.ended : e.status;

  int favoriteCount(int eventId) => favorites.where((f) => f.eventId == eventId).length;
  bool isFavorite(int eventId) => me != null && favorites.any((f) => f.participantId == me!.id && f.eventId == eventId);

  List<Event> searchEvents({
    String query = '',
    String? region,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    String sort = '최신순',
    Iterable<Event>? source,
  }) {
    final q = query.trim().toLowerCase();
    final list = (source ?? liveEvents).where((e) {
      if (q.isNotEmpty && !'${e.name} ${e.description} ${e.region}'.toLowerCase().contains(q)) return false;
      if (region != null && e.region != region) return false;
      if (categoryId != null && e.categoryId != categoryId) return false;
      // 기간이 겹치면 포함 (그 기간에 진행 중이거나 열릴 행사)
      if (from != null && e.endAt.isBefore(from)) return false;
      if (to != null && e.startAt.isAfter(to.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
    switch (sort) {
      case '관심순':
      case '인기순':
        list.sort((a, b) => favoriteCount(b.id).compareTo(favoriteCount(a.id)));
      case '마감임박순':
        list.removeWhere((e) => statusOf(e) == EventStatus.ended);
        list.sort((a, b) => a.endAt.compareTo(b.endAt));
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  // ============ 현황(주차·혼잡도) ============

  EventStatusSnapshot snapshot(int eventId) => snapshots.putIfAbsent(eventId, () => EventStatusSnapshot(eventId));

  bool _fresh(DateTime? t) => t != null && now().difference(t) < staleAfter;

  /// 화면에 보여 줄 주차 혼잡도. 진행 중이 아니거나 값이 오래되면 미확인.
  Level parkingLevelOf(Event e) {
    final s = snapshot(e.id);
    if (statusOf(e) != EventStatus.ongoing || !_fresh(s.parkingUpdatedAt)) return Level.unknown;
    return s.parkingLevel;
  }

  Level crowdLevelOf(Event e) {
    final s = snapshot(e.id);
    if (statusOf(e) != EventStatus.ongoing || !_fresh(s.crowdUpdatedAt)) return Level.unknown;
    return s.crowdLevel;
  }

  /// 주차 여유 비율 (총 면수-현재 대수)÷총 면수. 알 수 없으면 null.
  double? parkingFreeRatio(Event e) {
    final total = e.parkingTotal, cur = snapshot(e.id).parkingCurrent;
    if (total == null || total <= 0 || cur == null || parkingLevelOf(e) == Level.unknown) return null;
    return ((total - cur) / total).clamp(0, 1).toDouble();
  }

  /// 알고리즘 9-1: 비율 ≤ 0.5 여유, ≤ 0.7 보통, 그 위는 혼잡. 주차는 차 있는 비율에 같은 기준을 쓴다.
  static Level levelFromRatio(double usedRatio) =>
      usedRatio <= 0.5 ? Level.free : (usedRatio <= 0.7 ? Level.normal : Level.busy);

  String? updateParking(int eventId, int current) {
    final e = event(eventId);
    if (e == null) return '존재하지 않는 행사입니다';
    if (!_owns(e)) return '수정 권한이 없습니다';
    final total = e.parkingTotal;
    if (total == null) return '총 주차면수를 먼저 입력해 주세요';
    if (current < 0) return '현재 주차대수는 0 이상이어야 합니다';
    if (current > total) return '현재 대수는 총 면수보다 클 수 없습니다.';
    final s = snapshot(eventId);
    final before = s.parkingLevel;
    s.parkingCurrent = current;
    s.parkingLevel = total == 0 ? Level.busy : levelFromRatio(current / total);
    s.parkingUpdatedAt = now();
    if (s.parkingLevel != before) {
      _notifyFans(e, NotiType.parking, '${e.name} 주차장이 "${s.parkingLevel.label}" 상태가 되었어요');
    }
    notifyListeners();
    return null;
  }

  void recalcCrowd(int eventId) {
    final e = event(eventId);
    if (e == null) return;
    final since = now().subtract(crowdWindow);
    final n = visits.where((v) => v.eventId == eventId && v.visitedAt.isAfter(since)).length;
    final s = snapshot(eventId);
    final before = s.crowdLevel;
    s.crowdLevel = levelFromRatio(n / max(1, e.capacity));
    s.crowdUpdatedAt = now();
    if (s.crowdLevel != before && s.crowdLevel == Level.busy) {
      _notifyFans(e, NotiType.crowd, '${e.name} 현장이 혼잡해요. 방문 시간을 조정해 보세요');
    }
  }

  // ============ 관심 행사·방문 ============

  void toggleFavorite(int eventId) {
    final m = me;
    if (m == null || m.role != Role.participant) return;
    final had = favorites.where((f) => f.participantId == m.id && f.eventId == eventId).toList();
    if (had.isNotEmpty) {
      favorites.remove(had.first);
    } else if (event(eventId) != null) {
      favorites.add(FavoriteEvent(m.id, eventId));
    }
    notifyListeners();
  }

  List<Event> myFavoriteEvents() {
    final mine = favorites.where((f) => f.participantId == me?.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine.map((f) => event(f.eventId)).whereType<Event>().toList();
  }

  List<VisitRecord> myVisits() =>
      visits.where((v) => v.participantId == me?.id).toList()..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));

  static DateTime kstDate(DateTime t) {
    final k = t.toUtc().add(const Duration(hours: 9));
    return DateTime.utc(k.year, k.month, k.day);
  }

  EventGuide? guideByToken(String token) => guides.where((g) => g.qrToken == token.trim()).firstOrNull;

  /// 알고리즘 9: QR 값으로 가이드를 찾고, 오늘 그 행사 방문이 없으면 방문을 남기고 혼잡도를 다시 계산한다.
  /// 성공하면 가이드를, 실패하면 오류 문구를 돌려준다.
  (EventGuide?, String?) scanQr(String token, {VisitSource source = VisitSource.qr}) {
    final g = guideByToken(token);
    final e = g == null ? null : event(g.eventId);
    if (g == null || e == null) return (null, '올바른 축제 QR 코드가 아닙니다');
    final m = me;
    if (m != null && m.role == Role.participant) {
      final t = now(), d = kstDate(t);
      final already = visits.any((v) => v.participantId == m.id && v.eventId == e.id && v.visitDate == d);
      if (!already) {
        visits.add(VisitRecord(m.id, e.id, t, d, source));
        recalcCrowd(e.id);
      }
    }
    notifyListeners();
    return (g, null);
  }

  // ============ 알림 ============

  /// 알고리즘 15: 관심 등록한 참여자에게, 각자 설정이 켜져 있고 최근 같은 알림이 없을 때만 보낸다.
  void _notifyFans(Event e, NotiType type, String content) {
    final t = now();
    for (final f in favorites.where((f) => f.eventId == e.id)) {
      final p = findMember(Role.participant, f.participantId);
      if (p == null || !p.notifyEnabled) continue;
      if (type == NotiType.parking && !p.notifyParking) continue;
      if (type == NotiType.crowd && !p.notifyCrowd) continue;
      final dup = notifications.any((n) =>
          n.participantId == p.id && n.eventId == e.id && n.type == type && t.difference(n.createdAt) < notiDedupe);
      if (dup) continue;
      notifications.add(AppNotification(nextId(), p.id, e.id, type, content, t));
    }
  }

  List<AppNotification> myNotifications() =>
      notifications.where((n) => n.participantId == me?.id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadCount => myNotifications().where((n) => n.readAt == null).length;

  void markRead(AppNotification n) {
    n.readAt ??= now();
    notifyListeners();
  }

  void updateMe(void Function(Member m) change) {
    change(me!);
    me!.updatedAt = now();
    notifyListeners();
  }

  // ============ 개최자: 행사 ============

  bool _owns(Event e) => me != null && me!.role == Role.organizer && e.organizerId == me!.id;

  List<Event> myEvents() => liveEvents.where(_owns).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 행사 등록(id 0) 또는 수정. 오류 문구 또는 null.
  String? saveEvent(Event draft) {
    final m = me;
    if (m == null || m.role != Role.organizer) return '개최자만 등록할 수 있습니다';
    if (draft.name.trim().isEmpty || draft.description.trim().isEmpty || draft.address.trim().isEmpty) {
      return '필수 항목(축제 제목 등)을 입력해주세요';
    }
    if (draft.imageUrl.isEmpty) return '대표 이미지를 올려 주세요';
    if (!draft.endAt.isAfter(draft.startAt)) return '종료 일시는 시작 일시 이후여야 합니다';
    if (draft.capacity < 1) return '수용 인원은 1 이상이어야 합니다';
    if (draft.parkingTotal != null && draft.parkingTotal! < 1) return '총 면수는 1 이상으로 입력해 주세요.';
    if (category(draft.categoryId) == null) return '행사 종류를 골라 주세요';
    final dup = liveEvents.any((e) =>
        e.id != draft.id && e.name.trim() == draft.name.trim() && e.startAt.isAtSameMomentAs(draft.startAt));
    if (dup) return '같은 이름과 시작 일시의 행사가 이미 있습니다';

    if (draft.id == 0) {
      draft.id = nextId();
      events.add(draft);
      snapshot(draft.id);
    } else {
      final old = event(draft.id);
      if (old == null || !_owns(old)) return '수정 권한이 없습니다';
      events[events.indexOf(old)] = draft;
      draft.updatedAt = now();
      _notifyFans(draft, NotiType.eventUpdate, '관심 행사 "${draft.name}" 정보가 변경되었어요');
    }
    notifyListeners();
    return null;
  }

  String? deleteEvent(int id) {
    final e = event(id);
    if (e == null || !_owns(e)) return '삭제 권한이 없습니다';
    e.deletedAt = now();
    notifyListeners();
    return null;
  }

  // ============ 개최자: 가이드 ============

  List<EventGuide> guidesOf(int eventId) => guides.where((g) => g.eventId == eventId).toList();
  EventGuide? guide(int id) => guides.where((g) => g.id == id).firstOrNull;
  List<GuideSchedule> schedulesOf(int guideId) =>
      schedules.where((s) => s.guideId == guideId).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

  List<EventGuide> myGuides() {
    final ids = myEvents().map((e) => e.id).toSet();
    return guides.where((g) => ids.contains(g.eventId)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static String newQrToken() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// 일정끼리 겹치는지, 종료가 시작보다 뒤인지 본다 (알고리즘 3).
  static String? checkSchedules(List<GuideSchedule> list) {
    for (final s in list) {
      if (s.title.trim().isEmpty) return '일정 제목을 입력해 주세요';
      if (!s.endAt.isAfter(s.startAt)) return '"${s.title}" 일정의 종료 시각이 시작 시각보다 뒤여야 합니다';
    }
    final sorted = [...list]..sort((a, b) => a.startAt.compareTo(b.startAt));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].startAt.isBefore(sorted[i - 1].endAt)) {
        return '"${sorted[i - 1].title}"와 "${sorted[i].title}" 일정이 겹칩니다';
      }
    }
    return null;
  }

  /// 가이드 등록(guideId 0) 또는 수정. 성공하면 (가이드, null).
  (EventGuide?, String?) saveGuide({
    int guideId = 0,
    required int eventId,
    required String name,
    required String mapImageUrl,
    required String program,
    required List<GuideSchedule> items,
  }) {
    final e = event(eventId);
    if (e == null || !_owns(e)) return (null, '내가 등록한 행사를 골라 주세요');
    if (name.trim().isEmpty || mapImageUrl.isEmpty || program.trim().isEmpty) {
      return (null, '필수 가이드 정보를 입력해주세요');
    }
    final err = checkSchedules(items);
    if (err != null) return (null, err);

    EventGuide g;
    if (guideId == 0) {
      g = EventGuide(
          id: nextId(), eventId: eventId, guideName: name.trim(), mapImageUrl: mapImageUrl, program: program.trim(),
          qrToken: newQrToken());
      guides.add(g);
    } else {
      final old = guide(guideId);
      if (old == null || event(old.eventId) == null || !_owns(event(old.eventId)!)) return (null, '수정 권한이 없습니다');
      g = old
        ..eventId = eventId
        ..guideName = name.trim()
        ..mapImageUrl = mapImageUrl
        ..program = program.trim()
        ..updatedAt = now();
      schedules.removeWhere((s) => s.guideId == g.id);
    }
    for (final s in items) {
      schedules.add(GuideSchedule(id: nextId(), guideId: g.id, title: s.title.trim(), startAt: s.startAt, endAt: s.endAt));
    }
    notifyListeners();
    return (g, null);
  }

  String? deleteGuide(int id) {
    final g = guide(id);
    final e = g == null ? null : event(g.eventId);
    if (g == null || e == null || !_owns(e)) return '삭제 권한이 없습니다';
    guides.remove(g);
    schedules.removeWhere((s) => s.guideId == id);
    notifyListeners();
    return null;
  }

  String addLocalImage(Uint8List bytes) {
    final key = 'local:${nextId()}';
    localImages[key] = bytes;
    return key;
  }
}

/// 앱 전체가 함께 쓰는 저장소.
final store = AppStore();
