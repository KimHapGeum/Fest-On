// 저장소 표를 JSON으로 바꾸고 되돌린다. 서버 파일 저장과 앱-서버 사이 전송에 같이 쓴다.
// Flutter를 쓰지 않아 서버(server/)에서도 그대로 불러 쓴다.

import 'models.dart';
import 'store.dart';

String? _d(DateTime? t) => t?.toUtc().toIso8601String();
DateTime? _p(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();
DateTime _pp(Object? s) => DateTime.parse(s as String).toLocal();

Map<String, Object?> memberToJson(Member m) => {
      'id': m.id, 'role': m.role.name, 'loginId': m.loginId, 'passwordHash': m.passwordHash, 'name': m.name,
      'email': m.email, 'address': m.address, 'profileImageUrl': m.profileImageUrl, 'bio': m.bio,
      'termsAgreedAt': _d(m.termsAgreedAt), 'notifyEnabled': m.notifyEnabled, 'notifySound': m.notifySound,
      'notifyPreview': m.notifyPreview, 'notifyParking': m.notifyParking, 'notifyCrowd': m.notifyCrowd,
      'pushToken': m.pushToken, 'createdAt': _d(m.createdAt), 'updatedAt': _d(m.updatedAt), 'deletedAt': _d(m.deletedAt),
    };

Member memberFromJson(Map j) => Member(
      id: j['id'], role: Role.values.byName(j['role']), loginId: j['loginId'], passwordHash: j['passwordHash'],
      name: j['name'], email: j['email'], address: j['address'], profileImageUrl: j['profileImageUrl'], bio: j['bio'],
      termsAgreedAt: _p(j['termsAgreedAt']), notifyEnabled: j['notifyEnabled'], notifySound: j['notifySound'],
      notifyPreview: j['notifyPreview'], notifyParking: j['notifyParking'], notifyCrowd: j['notifyCrowd'],
      pushToken: j['pushToken'], createdAt: _pp(j['createdAt']),
    )
      ..updatedAt = _pp(j['updatedAt'])
      ..deletedAt = _p(j['deletedAt']);

Map<String, Object?> eventToJson(Event e) => {
      'id': e.id, 'organizerId': e.organizerId, 'name': e.name, 'imageUrl': e.imageUrl, 'description': e.description,
      'visitInfo': e.visitInfo, 'program': e.program, 'status': e.status.name, 'startAt': _d(e.startAt),
      'endAt': _d(e.endAt), 'region': e.region, 'categoryId': e.categoryId, 'address': e.address,
      'latitude': e.latitude, 'longitude': e.longitude, 'capacity': e.capacity, 'parkingLocation': e.parkingLocation,
      'parkingTotal': e.parkingTotal, 'createdAt': _d(e.createdAt), 'updatedAt': _d(e.updatedAt),
      'deletedAt': _d(e.deletedAt),
    };

Event eventFromJson(Map j) => Event(
      id: j['id'], organizerId: j['organizerId'], name: j['name'], imageUrl: j['imageUrl'],
      description: j['description'], visitInfo: j['visitInfo'], program: j['program'],
      status: EventStatus.values.byName(j['status']), startAt: _pp(j['startAt']), endAt: _pp(j['endAt']),
      region: j['region'], categoryId: j['categoryId'], address: j['address'],
      latitude: (j['latitude'] as num).toDouble(), longitude: (j['longitude'] as num).toDouble(),
      capacity: j['capacity'], parkingLocation: j['parkingLocation'], parkingTotal: j['parkingTotal'],
      createdAt: _p(j['createdAt']),
    )
      ..updatedAt = _p(j['updatedAt']) ?? DateTime.now()
      ..deletedAt = _p(j['deletedAt']);

Map<String, Object?> scheduleToJson(GuideSchedule s) => {
      'id': s.id, 'guideId': s.guideId, 'title': s.title, 'startAt': _d(s.startAt), 'endAt': _d(s.endAt),
      'createdAt': _d(s.createdAt), 'updatedAt': _d(s.updatedAt),
    };

GuideSchedule scheduleFromJson(Map j) => GuideSchedule(
      id: j['id'] ?? 0, guideId: j['guideId'] ?? 0, title: j['title'], startAt: _pp(j['startAt']),
      endAt: _pp(j['endAt']), createdAt: _p(j['createdAt']),
    )..updatedAt = _p(j['updatedAt']) ?? DateTime.now();

/// [viewer]가 있으면 그 회원에게 보낼 값만 남긴다: 남의 비밀번호 해시·이메일·방문·알림, 소셜 연결은 빼고,
/// 내 비밀번호 해시는 있다는 표시('*')만 보낸다. [viewer] 없이 [full]이면 서버 파일용으로 전부 담는다.
Map<String, Object?> dumpState(AppStore s, {Member? viewer, bool full = false}) {
  bool mine(Member m) => viewer != null && m.role == viewer.role && m.id == viewer.id;
  Map<String, Object?> member(Member m) {
    final j = memberToJson(m);
    if (full) return j;
    if (!mine(m)) {
      j.addAll({'loginId': null, 'passwordHash': null, 'email': '', 'pushToken': null});
    } else if (m.passwordHash != null) {
      j['passwordHash'] = '*';
    }
    return j;
  }

  final pid = viewer?.role == Role.participant ? viewer!.id : null;
  return {
    'seq': s.seq,
    if (!full) 'me': viewer == null ? null : {'role': viewer.role.name, 'id': viewer.id},
    'participants': s.participants.map(member).toList(),
    'organizers': s.organizers.map(member).toList(),
    'socials': [
      if (full)
        for (final a in s.socials)
          {'id': a.id, 'memberId': a.memberId, 'role': a.role.name, 'provider': a.provider.name,
            'providerUserId': a.providerUserId, 'createdAt': _d(a.createdAt)},
    ],
    'categories': [for (final c in s.categories) {'id': c.id, 'name': c.name}],
    'events': s.events.map(eventToJson).toList(),
    'snapshots': [
      for (final x in s.snapshots.values)
        {'eventId': x.eventId, 'parkingCurrent': x.parkingCurrent, 'parkingLevel': x.parkingLevel.name,
          'parkingUpdatedAt': _d(x.parkingUpdatedAt), 'crowdLevel': x.crowdLevel.name,
          'crowdUpdatedAt': _d(x.crowdUpdatedAt)},
    ],
    'guides': [
      for (final g in s.guides)
        {'id': g.id, 'eventId': g.eventId, 'guideName': g.guideName, 'mapImageUrl': g.mapImageUrl,
          'program': g.program, 'qrToken': g.qrToken, 'createdAt': _d(g.createdAt), 'updatedAt': _d(g.updatedAt)},
    ],
    'schedules': s.schedules.map(scheduleToJson).toList(),
    'favorites': [
      for (final f in s.favorites) {'participantId': f.participantId, 'eventId': f.eventId, 'createdAt': _d(f.createdAt)},
    ],
    'visits': [
      for (final v in s.visits)
        if (full || v.participantId == pid)
          {'participantId': v.participantId, 'eventId': v.eventId, 'visitedAt': _d(v.visitedAt),
            'visitDate': _d(v.visitDate), 'source': v.source.name},
    ],
    'notifications': [
      for (final n in s.notifications)
        if (full || n.participantId == pid)
          {'id': n.id, 'participantId': n.participantId, 'eventId': n.eventId, 'type': n.type.name,
            'content': n.content, 'readAt': _d(n.readAt), 'createdAt': _d(n.createdAt)},
    ],
  };
}

/// [dumpState]로 만든 값으로 표를 모두 바꾼다. 'me'가 있으면 로그인한 회원도 그 값으로 바꾼다.
void loadState(AppStore s, Map j) {
  List<Map> rows(String k) => (j[k] as List).cast<Map>();
  s
    ..participants.setTo(rows('participants').map(memberFromJson))
    ..organizers.setTo(rows('organizers').map(memberFromJson))
    ..socials.setTo(rows('socials').map((a) => SocialAccount(a['id'], a['memberId'], Role.values.byName(a['role']),
        SocialProvider.values.byName(a['provider']), a['providerUserId'], createdAt: _p(a['createdAt']))))
    ..categories.setTo(rows('categories').map((c) => Category(c['id'], c['name'])))
    ..events.setTo(rows('events').map(eventFromJson))
    ..guides.setTo(rows('guides').map((g) => EventGuide(
        id: g['id'], eventId: g['eventId'], guideName: g['guideName'], mapImageUrl: g['mapImageUrl'],
        program: g['program'], qrToken: g['qrToken'], createdAt: _p(g['createdAt']))
      ..updatedAt = _pp(g['updatedAt'])))
    ..schedules.setTo(rows('schedules').map(scheduleFromJson))
    ..favorites.setTo(rows('favorites')
        .map((f) => FavoriteEvent(f['participantId'], f['eventId'], createdAt: _p(f['createdAt']))))
    ..visits.setTo(rows('visits').map((v) => VisitRecord(v['participantId'], v['eventId'], _pp(v['visitedAt']),
        DateTime.parse(v['visitDate']), VisitSource.values.byName(v['source'])))) // 날짜 비교가 UTC 값끼리라 UTC 그대로 둔다
    ..notifications.setTo(rows('notifications').map((n) => AppNotification(n['id'], n['participantId'],
        n['eventId'], NotiType.values.byName(n['type']), n['content'], _pp(n['createdAt']))
      ..readAt = _p(n['readAt'])))
    ..seq = j['seq'];
  s.snapshots
    ..clear()
    ..addEntries(rows('snapshots').map((x) => MapEntry(
        x['eventId'] as int,
        EventStatusSnapshot(x['eventId'])
          ..parkingCurrent = x['parkingCurrent']
          ..parkingLevel = Level.values.byName(x['parkingLevel'])
          ..parkingUpdatedAt = _p(x['parkingUpdatedAt'])
          ..crowdLevel = Level.values.byName(x['crowdLevel'])
          ..crowdUpdatedAt = _p(x['crowdUpdatedAt']))));
  if (j.containsKey('me')) {
    final me = j['me'] as Map?;
    s.me = me == null ? null : s.findMember(Role.values.byName(me['role']), me['id']);
  }
}

extension<T> on List<T> {
  void setTo(Iterable<T> items) => this
    ..clear()
    ..addAll(items);
}
