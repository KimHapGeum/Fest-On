import 'package:fest_on/models.dart';
import 'package:fest_on/real_events.dart';
import 'package:fest_on/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime t;
  late AppStore s;

  setUp(() {
    t = DateTime(2026, 11, 16, 14);
    s = AppStore(clock: () => t);
  });

  test('비밀번호 규칙: 영문+숫자 6~16자', () {
    expect(AppStore.checkPassword('pass1234'), isNull);
    expect(AppStore.checkPassword('password123!'), isNull);
    expect(AppStore.checkPassword('1234'), isNotNull);
    expect(AppStore.checkPassword('123456'), isNotNull); // 숫자만
    expect(AppStore.checkPassword('abcdefgh'), isNotNull); // 영문만
    expect(AppStore.checkPassword('a1' * 9), isNotNull); // 18자
  });

  test('회원가입 검증과 로그인', () {
    String? sign(String id, String email, String pw, String pw2, {bool terms = true}) => s.signup(
        role: Role.participant, loginId: id, name: '새사람', email: email, password: pw, passwordConfirm: pw2,
        termsAgreed: terms);
    expect(sign('new1', 'new@x.com', 'pass1234', 'pass9999'), '비밀번호가 일치하지 않습니다');
    expect(sign('new1', 'new@x.com', 'pass1234', 'pass1234', terms: false), '필수 약관에 모두 동의해주세요');
    expect(sign('user1', 'new@x.com', 'pass1234', 'pass1234'), '이미 사용 중인 아이디입니다');
    expect(sign('new1', 'notanemail', 'pass1234', 'pass1234'), isNotNull);
    expect(sign('new1', 'new@x.com', 'pass1234', 'pass1234'), isNull);
    expect(s.login(Role.participant, 'new@x.com', 'pass1234'), isNull); // 이메일로도 로그인
    expect(s.login(Role.participant, 'new1', 'wrong1234'), '아이디 또는 비밀번호가 일치하지 않습니다');
    expect(s.login(Role.organizer, 'new1', 'pass1234'), isNotNull); // 역할이 다르면 다른 테이블
  });

  test('탈퇴한 회원의 아이디로 다시 가입할 수 있다', () {
    s.login(Role.participant, 'user1', 'pass1234');
    s.withdraw();
    expect(s.login(Role.participant, 'user1', 'pass1234'), isNotNull);
    expect(
        s.signup(role: Role.participant, loginId: 'user1', name: 'a', email: 'testuser@example.com', password: 'pass1234',
            passwordConfirm: 'pass1234', termsAgreed: true),
        isNull);
  });

  test('혼잡도 기준: 0.5 이하 여유, 0.7 이하 보통, 초과 혼잡', () {
    expect(AppStore.levelFromRatio(0.5), Level.free);
    expect(AppStore.levelFromRatio(0.51), Level.normal);
    expect(AppStore.levelFromRatio(0.7), Level.normal);
    expect(AppStore.levelFromRatio(0.71), Level.busy);
  });

  test('QR 방문은 같은 날 같은 행사에 한 번만 기록되고 혼잡도를 다시 계산한다', () {
    s.login(Role.participant, 'user1', 'pass1234');
    final g = s.guides.first;
    final before = s.visits.where((v) => v.eventId == g.eventId).length;
    final (found, err) = s.scanQr(g.qrToken);
    expect(err, isNull);
    expect(found, g);
    s.scanQr(g.qrToken);
    expect(s.visits.where((v) => v.eventId == g.eventId).length, before + 1);
    expect(s.snapshot(g.eventId).crowdUpdatedAt, t);
    expect(s.scanQr('nope').$2, '올바른 축제 QR 코드가 아닙니다');

    t = t.add(const Duration(days: 1));
    s.scanQr(g.qrToken);
    expect(s.visits.where((v) => v.eventId == g.eventId).length, before + 2);
  });

  test('진행 중이 아니거나 값이 오래되면 미확인', () {
    final dodream = s.liveEvents.firstWhere((e) => e.name.contains('두드림'));
    final fireworks = s.liveEvents.firstWhere((e) => e.name.contains('불꽃'));
    expect(s.crowdLevelOf(dodream), Level.busy);
    expect(s.parkingLevelOf(fireworks), Level.unknown);
    t = t.add(const Duration(hours: 3));
    expect(s.crowdLevelOf(dodream), Level.unknown);
  });

  test('주차 입력은 개최자 본인만, 혼잡도가 바뀌면 관심 참여자에게 알림', () {
    final dodream = s.liveEvents.firstWhere((e) => e.name.contains('두드림'));
    expect(s.updateParking(dodream.id, 10), isNotNull); // 로그인 안 함
    s.login(Role.organizer, 'org2', 'pass1234');
    expect(s.updateParking(dodream.id, 10), '수정 권한이 없습니다');
    s.login(Role.organizer, 'org1', 'pass1234');
    final before = s.notifications.where((n) => n.participantId == 1 && n.type == NotiType.parking).length;
    expect(s.updateParking(dodream.id, 10), isNull);
    expect(s.snapshot(dodream.id).parkingLevel, Level.free);
    expect(s.notifications.where((n) => n.participantId == 1 && n.type == NotiType.parking).length, before + 1);
    expect(s.parkingFreeRatio(dodream), closeTo(0.95, 0.001));

    // 주차 알림을 끈 참여자는 받지 않는다
    s.participants.first.notifyParking = false;
    s.updateParking(dodream.id, 199);
    expect(s.notifications.where((n) => n.participantId == 1 && n.type == NotiType.parking).length, before + 1);
  });

  test('일정 겹침과 순서 검사', () {
    GuideSchedule g(String title, int from, int to) =>
        GuideSchedule(title: title, startAt: DateTime(2026, 1, 1, from), endAt: DateTime(2026, 1, 1, to));
    expect(AppStore.checkSchedules([g('a', 10, 11), g('b', 11, 12)]), isNull);
    expect(AppStore.checkSchedules([g('a', 10, 12), g('b', 11, 13)]), contains('겹칩니다'));
    expect(AppStore.checkSchedules([g('a', 12, 10)]), contains('뒤여야'));
  });

  test('행사 등록 검증: 같은 이름·시작 일시 중복, 종료 일시 순서', () {
    s.login(Role.organizer, 'org1', 'pass1234');
    final base = s.liveEvents.first;
    Event draft({String? name, DateTime? end}) => Event(
          id: 0, organizerId: 2, name: name ?? base.name, imageUrl: 'placeholder:x', description: 'd',
          startAt: base.startAt, endAt: end ?? base.endAt, region: '서울', categoryId: 1, address: 'a',
          latitude: 37, longitude: 127, capacity: 10);
    expect(s.saveEvent(draft()), contains('이미 있습니다'));
    expect(s.saveEvent(draft(name: '새 행사', end: base.startAt)), contains('이후여야'));
    expect(s.saveEvent(draft(name: '새 행사')), isNull);
  });

  test('테스트 보고서 결함: 비밀번호 17자, 휴대폰 번호, 주차 면수, 종료 행사 가이드', () {
    expect(AppStore.checkPassword('Test1234!Test123'), isNull); // 16자 (BUG-003 경계)
    expect(AppStore.checkPassword('Test1234!Test1234'), isNotNull); // 17자
    expect(AppStore.isPhone('01012345678'), isTrue);
    expect(AppStore.isPhone('010-1234-5678'), isTrue);
    expect(AppStore.isPhone('0101234567'), isFalse); // BUG-004: 010인데 10자리
    expect(AppStore.isPhone('0111234567'), isTrue);

    s.login(Role.organizer, 'org1', 'pass1234');
    final base = s.liveEvents.first;
    Event draft(int parking) => Event(
        id: 0, organizerId: 2, name: '주차 시험', imageUrl: 'placeholder:x', description: 'd', startAt: base.startAt,
        endAt: base.endAt, region: '서울', categoryId: 1, address: 'a', latitude: 37, longitude: 127, capacity: 10,
        parkingTotal: parking);
    expect(s.saveEvent(draft(0)), contains('1 이상')); // BUG-012
    final ok = draft(100);
    expect(s.saveEvent(ok), isNull);
    expect(s.updateParking(ok.id, 101), contains('클 수 없습니다')); // BUG-013
    expect(s.updateParking(ok.id, 100), isNull);

    // BUG-007: 종료된 행사에도 가이드가 있어야 [종료] 탭이 비지 않는다
    expect(s.guides.any((g) => s.statusOf(s.event(g.eventId)!) == EventStatus.ended), isTrue);
  });

  test('실제 축제 데이터: 지역·종류·기간·좌표가 앱 규칙에 맞다', () {
    final real = s.liveEvents.where((e) => e.organizerId == 4).toList();
    expect(real.length, realEvents.length);
    for (final e in real) {
      expect(AppStore.regions, contains(e.region), reason: e.name);
      expect(s.category(e.categoryId), isNotNull, reason: e.name);
      expect(e.endAt.isAfter(e.startAt), isTrue, reason: e.name);
      expect(e.latitude, inInclusiveRange(33, 39), reason: e.name);
      expect(e.longitude, inInclusiveRange(124, 132), reason: e.name);
    }
    // 시험 시계 2026-11-16 기준: 10.16~12.06 전시는 진행중, 2027-01-09 화천 산천어축제는 예정, 7월 안동 수페스타는 종료
    expect(s.statusOf(real.firstWhere((e) => e.name == '《소장품, 시대의 장면들》')), EventStatus.ongoing);
    expect(s.statusOf(real.firstWhere((e) => e.name == '얼음나라화천 산천어축제')), EventStatus.ready);
    expect(s.statusOf(real.firstWhere((e) => e.name == '안동 수(水)페스타')), EventStatus.ended);
  });

  test('관심순 정렬과 관심 토글', () {
    s.login(Role.participant, 'user1', 'pass1234');
    final top = s.searchEvents(sort: '관심순').first;
    expect(top.name, contains('불꽃'));
    final id = s.liveEvents.firstWhere((e) => !s.isFavorite(e.id)).id;
    s.toggleFavorite(id);
    expect(s.isFavorite(id), isTrue);
    s.toggleFavorite(id);
    expect(s.isFavorite(id), isFalse);
  });
}
