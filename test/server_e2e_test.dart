// 켜 둔 로컬 서버와 앱 쪽 요청 코드(lib/api.dart)를 함께 본다. 서버 주소를 줄 때만 돈다:
//   (server 폴더) dart run bin/server.dart
//   flutter test test/server_e2e_test.dart --dart-define=API_URL=http://127.0.0.1:8080
import 'package:fest_on/api.dart';
import 'package:fest_on/models.dart';
import 'package:fest_on/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('서버로 로그인·관심 행사·로그아웃', () async {
    await pull();
    expect(store.liveEvents, isNotEmpty, reason: '서버의 행사 목록을 받아 온다');
    expect(store.me, isNull);

    expect(await actErr('login', {'role': 'participant', 'id': 'user1', 'password': 'pass1234'}), isNull);
    expect(store.me?.loginId, 'user1');
    expect(sessionToken, isNotNull);

    final e = store.liveEvents.last;
    final had = store.isFavorite(e.id);
    expect(await actErr('toggleFavorite', {'eventId': e.id}), isNull);
    expect(store.isFavorite(e.id), !had);
    await actErr('toggleFavorite', {'eventId': e.id}); // 되돌려 둔다
    expect(store.isFavorite(e.id), had);

    final (_, err) = await actPair('scanQr', {'token': 'not-a-token'});
    expect(err, '올바른 축제 QR 코드가 아닙니다');
    expect(store.organizers.every((m) => m.passwordHash == null), isTrue);

    await actErr('logout');
    expect(store.me, isNull);
    expect(sessionToken, isNull);
    expect(await actErr('login', {'role': Role.organizer.name, 'id': 'org1', 'password': 'nope12'}),
        '아이디 또는 비밀번호가 일치하지 않습니다');
  }, skip: apiUrl.isEmpty ? 'API_URL을 주고 서버를 켰을 때만 돈다' : null);
}
