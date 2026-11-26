// 화면이 저장소를 바꿀 때 부르는 곳. API_URL이 있으면 로컬 서버에 보내고, 없으면 앱 메모리 저장소에서 바로 돌린다.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'actions.dart';
import 'codec.dart';
import 'store.dart';

bool get online => apiUrl.isNotEmpty;

/// 서버가 로그인 때 준 세션 값. 자동 로그인을 켜면 기기에 남긴다.
String? sessionToken;
int _version = -1;
Timer? _poll;

Map<String, String> get _headers =>
    {'content-type': 'application/json', if (sessionToken != null) 'authorization': 'Bearer $sessionToken'};

/// 서버에 못 닿았거나 서버가 요청을 거절했을 때.
class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

void _apply(Map<String, Object?> j) {
  if (j.containsKey('token')) sessionToken = j['token'] as String?;
  final state = j['state'] as Map<String, Object?>?;
  if (state == null) return;
  _version = state['version'] as int;
  loadState(store, state);
  store.touch();
}

Future<Map<String, Object?>> _send(Future<http.Response> req) async {
  final http.Response r;
  try {
    r = await req.timeout(const Duration(seconds: 10));
  } catch (_) {
    throw ApiError('서버에 연결할 수 없습니다. 로컬 서버가 켜져 있는지 확인해 주세요');
  }
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
  if (r.statusCode != 200) throw ApiError(j['error'] as String? ?? '서버 오류 (${r.statusCode})');
  return j;
}

/// [runAction]의 요청 하나를 보낸다. 서버 응답의 최신 표로 앱 저장소를 바꾼 뒤 결과를 돌려준다.
Future<Object?> act(String name, [Map<String, Object?> args = const {}]) async {
  if (!online) return runAction(store, name, args);
  final j = await _send(http.post(Uri.parse('$apiUrl/api/act'),
      headers: _headers, body: jsonEncode({'name': name, 'args': args})));
  _apply(j);
  return j['result'];
}

/// 오류 문구를 돌려주는 요청. 연결 오류도 문구로 돌려준다.
Future<String?> actErr(String name, [Map<String, Object?> args = const {}]) async {
  try {
    return await act(name, args) as String?;
  } on ApiError catch (e) {
    return e.message;
  }
}

/// (번호, 오류) 짝을 돌려주는 요청: saveEvent, saveGuide, scanQr.
Future<(int?, String?)> actPair(String name, Map<String, Object?> args) async {
  try {
    final r = await act(name, args) as List;
    return (r[0] as int?, r[1] as String?);
  } on ApiError catch (e) {
    return (null, e.message);
  }
}

/// 서버의 최신 표를 받아 온다. 바뀐 게 없으면 서버가 표를 다시 보내지 않는다.
Future<void> pull() async {
  if (!online) return;
  _apply(await _send(http.get(Uri.parse('$apiUrl/api/state?v=$_version'), headers: _headers)));
}

/// 다른 기기가 바꾼 값(방문·혼잡도·알림)이 보이도록 몇 초마다 받아 온다.
void startPolling() {
  if (!online) return;
  _poll ??= Timer.periodic(const Duration(seconds: 5), (_) => pull().catchError((_) {}));
}

/// 사진을 올리고 image_url에 넣을 값을 돌려준다. 서버가 없으면 앱 메모리에 둔다.
Future<String> uploadImage(Uint8List bytes, String fileName) async {
  if (!online) return store.addLocalImage(bytes);
  final j = await _send(http.post(Uri.parse('$apiUrl/api/image'),
      headers: _headers, body: jsonEncode({'name': fileName, 'data': base64Encode(bytes)})));
  return j['url'] as String;
}

/// 서버가 준 '/images/…' 주소를 그릴 수 있는 전체 주소로 바꾼다.
String imageSrc(String url) => url.startsWith('/images/') ? '$apiUrl$url' : url;
