import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../lib/codec.dart';
import '../../lib/models.dart';
import '../../lib/store.dart';
import '../bin/server.dart';

void main() {
  late Directory dir;
  late FestServer app;
  final t = DateTime(2026, 11, 16, 14);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fest_server_test');
    app = FestServer(dir, clock: () => t);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, Map<String, Object?>)> call(String method, String path, {Object? body, String? token}) async {
    final r = await app.handle(Request(method, Uri.parse('http://localhost/$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {if (token != null) 'authorization': 'Bearer $token'}));
    return (r.statusCode, jsonDecode(await r.readAsString()) as Map<String, Object?>);
  }

  Future<Map<String, Object?>> act(String name, Map<String, Object?> args, {String? token}) async =>
      (await call('POST', 'api/act', body: {'name': name, 'args': args}, token: token)).$2;

  test('시연 데이터와 실제 축제를 넣어 시작하고 db.json에 남긴다', () {
    expect(File('${dir.path}/db.json').existsSync(), isTrue);
    expect(app.store.liveEvents.length, greaterThan(100));
    expect(app.store.findMember(Role.participant, 1)?.loginId, 'user1');
  });

  test('로그인하면 세션을 주고, 남의 비밀번호 해시·이메일은 보내지 않는다', () async {
    final bad = await act('login', {'role': 'participant', 'id': 'user1', 'password': 'wrong1'});
    expect(bad['result'], '아이디 또는 비밀번호가 일치하지 않습니다');
    expect(bad.containsKey('token'), isFalse);

    final ok = await act('login', {'role': 'participant', 'id': 'user1', 'password': 'pass1234'});
    expect(ok['result'], isNull);
    final token = ok['token'] as String;
    final state = ok['state'] as Map;
    expect(state['me'], {'role': 'participant', 'id': 1});
    final orgs = (state['organizers'] as List).cast<Map>();
    expect(orgs.every((m) => m['passwordHash'] == null && m['email'] == ''), isTrue);
    expect(app.store.me, isNull, reason: '요청이 끝나면 서버 저장소의 로그인은 비워 둔다');

    final (_, s) = await call('GET', 'api/state', token: token);
    expect((s['state'] as Map)['me'], {'role': 'participant', 'id': 1});
  });

  test('관심 행사·QR 방문이 서버를 다시 켜도 남는다', () async {
    final token = (await act('login', {'role': 'participant', 'id': 'user1', 'password': 'pass1234'}))['token'] as String;
    final eventId = app.store.liveEvents.firstWhere((e) => !app.store.favorites.any((f) => f.eventId == e.id)).id;
    await act('toggleFavorite', {'eventId': eventId}, token: token);
    final guide = app.store.guides.first;
    final scan = await act('scanQr', {'token': guide.qrToken}, token: token);
    expect(scan['result'], [guide.id, null]);

    final again = FestServer(dir, clock: () => t);
    expect(again.store.favorites.any((f) => f.participantId == 1 && f.eventId == eventId), isTrue);
    expect(again.store.visits.any((v) => v.participantId == 1 && v.eventId == guide.eventId && v.visitDate == AppStore.kstDate(t)),
        isTrue);
    expect(again.version, app.version);
    expect(again.store.seq, app.store.seq);
  });

  test('세션 없이 바꾸려 하거나 남의 행사를 고치면 거절한다', () async {
    final e = app.store.liveEvents.firstWhere((e) => e.organizerId == 2); // org1의 행사
    expect((await act('updateParking', {'eventId': e.id, 'current': 1}))['result'], '수정 권한이 없습니다');

    final org2 = (await act('login', {'role': 'organizer', 'id': 'org2', 'password': 'pass1234'}))['token'] as String;
    expect((await act('deleteEvent', {'id': e.id}, token: org2))['result'], '삭제 권한이 없습니다');

    final fake = {...eventToJson(e), 'id': 0, 'name': '가짜 행사'}; // 다른 개최자 번호로 등록 시도
    expect((await act('saveEvent', {'event': fake}, token: org2))['result'], [null, '개최자만 등록할 수 있습니다']);

    final (code, _) = await call('POST', 'api/act', body: {'name': 'nope', 'args': {}});
    expect(code, 400);
  });

  test('로그아웃하면 세션을 지운다', () async {
    final token = (await act('login', {'role': 'organizer', 'id': 'org1', 'password': 'pass1234'}))['token'] as String;
    final out = await act('logout', {}, token: token);
    expect(out['token'], isNull);
    expect(app.sessions.containsKey(token), isFalse);
  });

  test('사진은 로그인해야 올리고, 숫자 이름 파일만 내준다', () async {
    final png = base64Encode([137, 80, 78, 71]);
    expect((await call('POST', 'api/image', body: {'name': 'a.png', 'data': png})).$1, 401);
    final token = (await act('login', {'role': 'organizer', 'id': 'org1', 'password': 'pass1234'}))['token'] as String;
    expect((await call('POST', 'api/image', body: {'name': 'a.exe', 'data': png}, token: token)).$1, 400);
    final (code, j) = await call('POST', 'api/image', body: {'name': 'a.png', 'data': png}, token: token);
    expect(code, 200);
    final url = j['url'] as String;
    final r = await app.handle(Request('GET', Uri.parse('http://localhost$url')));
    expect(r.statusCode, 200);
    expect(await r.read().expand((b) => b).toList(), [137, 80, 78, 71]);
    expect((await app.handle(Request('GET', Uri.parse('http://localhost/images/..%2Fdb.json')))).statusCode, 404);
  });
}
