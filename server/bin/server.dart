// 라두나(Fest-On) 로컬 서버.
// 앱의 lib/store.dart를 그대로 불러 같은 규칙(인증·방문·혼잡도·알림·권한)을 서버에서 돌리고, 표는 data/db.json에 남긴다.
// 실행: server 폴더에서 `dart run bin/server.dart` (같은 와이파이의 폰에서 접속하려면 `--lan`)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import '../../lib/actions.dart';
import '../../lib/codec.dart';
import '../../lib/models.dart';
import '../../lib/store.dart';

const _imageTypes = {
  'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'gif': 'image/gif', 'webp': 'image/webp',
  'heic': 'image/heic',
};
const _maxImage = 5 * 1024 * 1024; // 앱의 사진 크기 제한과 같다
const _cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

class FestServer {
  /// [dir]에 db.json이 없으면 앱의 시연 데이터(lib/seed.dart, 실제 축제 목록 포함)로 처음 채운다.
  FestServer(this.dir, {DateTime Function()? clock}) {
    final f = _db;
    store = AppStore(clock: clock, seed: !f.existsSync());
    if (f.existsSync()) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      loadState(store, j);
      version = j['version'] as int;
      sessions.addAll((j['sessions'] as Map).cast());
    } else {
      _save();
    }
    store.me = null;
  }

  final Directory dir;
  late final AppStore store;

  /// 세션 값 → '역할:회원번호'.
  /// shortcut: 세션이 만료되지 않는다. 실제로 배포하면 만료 시각을 두고 HTTPS로만 받는다.
  final sessions = <String, String>{};
  int version = 0;

  File get _db => File('${dir.path}/db.json');
  Directory get _images => Directory('${dir.path}/images');

  void _save() {
    final j = dumpState(store, full: true)..addAll({'version': version, 'sessions': sessions});
    final tmp = File('${dir.path}/db.json.tmp')..writeAsStringSync(jsonEncode(j));
    // OneDrive가 동기화 중이면 잠깐 막힐 수 있어 몇 번 다시 해 본다
    for (var i = 0;; i++) {
      try {
        tmp.renameSync(_db.path);
        return;
      } on FileSystemException {
        if (i >= 5) rethrow;
        sleep(const Duration(milliseconds: 300));
      }
    }
  }

  String? _token(Request r) {
    final h = r.headers['authorization'];
    return h != null && h.startsWith('Bearer ') ? h.substring(7) : null;
  }

  Member? _viewer(String? token) {
    final v = token == null ? null : sessions[token];
    if (v == null) return null;
    final [role, id] = v.split(':');
    return store.findMember(Role.values.byName(role), int.parse(id));
  }

  String _newSession(Member m) {
    final r = Random.secure();
    final t = List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    sessions[t] = '${m.role.name}:${m.id}';
    return t;
  }

  Map<String, Object?> _state(Member? viewer) => dumpState(store, viewer: viewer)..['version'] = version;

  Response _json(Object body, [int status = 200]) =>
      Response(status, body: jsonEncode(body), headers: {..._cors, 'content-type': 'application/json; charset=utf-8'});

  Future<Response> handle(Request r) async {
    if (r.method == 'OPTIONS') return Response.ok('', headers: _cors);
    try {
      final path = r.url.path;
      if (r.method == 'GET' && path == '') return _json({'ok': true, 'name': '라두나 로컬 서버', 'version': version});
      if (r.method == 'GET' && path == 'api/state') return _getState(r);
      if (r.method == 'POST' && path == 'api/act') return await _act(r);
      if (r.method == 'POST' && path == 'api/image') return await _upload(r);
      if (r.method == 'GET' && path.startsWith('images/')) return _image(path.substring(7));
      return _json({'error': '없는 주소입니다'}, 404);
    } on FormatException catch (e) {
      return _json({'error': '잘못된 요청입니다: ${e.message}'}, 400);
    } on ArgumentError catch (e) {
      return _json({'error': '잘못된 요청입니다: ${e.message}'}, 400);
    } on TypeError {
      return _json({'error': '잘못된 요청입니다: 값의 모양이 맞지 않습니다'}, 400);
    }
  }

  Response _getState(Request r) {
    // 앱이 가진 판과 같으면 표를 다시 보내지 않는다 (5초마다 묻기 때문)
    if (r.url.queryParameters['v'] == '$version') return _json({});
    return _json({'state': _state(_viewer(_token(r)))});
  }

  Future<Response> _act(Request r) async {
    final body = jsonDecode(await r.readAsString()) as Map<String, Object?>;
    final name = body['name'] as String;
    final args = (body['args'] as Map? ?? {}).cast<String, Object?>();
    final token = _token(r);
    final before = _viewer(token);

    // 여기부터 응답까지는 기다림(await)이 없어 요청이 섞이지 않는다
    store.me = before;
    final Object? result;
    final Member? after;
    try {
      result = runAction(store, name, args);
    } finally {
      after = store.me;
      store.me = null;
    }

    final loginChanged = !identical(before, after); // 로그인·로그아웃·탈퇴
    String? newToken;
    if (loginChanged) {
      if (token != null) sessions.remove(token);
      if (after != null) newToken = _newSession(after);
    }
    if (name != 'findLoginIds' || loginChanged) {
      version++;
      _save();
    }
    return _json({'result': result, if (loginChanged) 'token': newToken, 'state': _state(after)});
  }

  Future<Response> _upload(Request r) async {
    if (_viewer(_token(r)) == null) return _json({'error': '로그인이 필요합니다'}, 401);
    if ((r.contentLength ?? 0) > _maxImage * 2) return _json({'error': '5MB 이하의 이미지만 올릴 수 있습니다'}, 400);
    final body = jsonDecode(await r.readAsString()) as Map<String, Object?>;
    final ext = (body['name'] as String).split('.').last.toLowerCase();
    if (!_imageTypes.containsKey(ext)) return _json({'error': '이미지 파일만 첨부 가능합니다'}, 400);
    final bytes = base64Decode(body['data'] as String);
    if (bytes.length > _maxImage) return _json({'error': '5MB 이하의 이미지만 올릴 수 있습니다'}, 400);
    final file = '${store.nextId()}.$ext';
    _images.createSync(recursive: true);
    File('${_images.path}/$file').writeAsBytesSync(bytes);
    version++;
    _save(); // 사진 번호가 다시 쓰이지 않게 다음 번호를 남긴다
    return _json({'url': '/images/$file'});
  }

  Response _image(String name) {
    final m = RegExp(r'^\d+\.([a-z]+)$').firstMatch(name); // 숫자.확장자만 받아 다른 경로로 못 나가게 한다
    final type = m == null ? null : _imageTypes[m[1]];
    final f = File('${_images.path}/$name');
    if (type == null || !f.existsSync()) return _json({'error': '없는 사진입니다'}, 404);
    return Response.ok(f.readAsBytesSync(), headers: {..._cors, 'content-type': type});
  }
}

Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final lan = args.contains('--lan');
  final dir = Directory('data')..createSync(recursive: true);
  final app = FestServer(dir);
  final s = await io.serve(app.handle, lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4, port);
  print('라두나 로컬 서버: http://127.0.0.1:${s.port}  (데이터: ${dir.absolute.path})');
  print('행사 ${app.store.liveEvents.length}개, 참여자 ${app.store.participants.length}명, 개최자 ${app.store.organizers.length}명');
  if (lan) print('같은 와이파이의 폰에서는 이 컴퓨터의 IP 주소:${s.port}로 접속합니다');
}
