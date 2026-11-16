import 'package:fest_on/models.dart';
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
