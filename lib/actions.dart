// 화면이 저장소를 바꾸는 일을 이름과 JSON 인자로 부른다.
// 서버는 받은 요청을 이 함수로 돌리고, 서버 없이 쓸 때는 앱이 같은 함수를 자기 저장소에 돌린다.
// Flutter를 쓰지 않아 서버(server/)에서도 그대로 불러 쓴다.

import 'codec.dart';
import 'models.dart';
import 'store.dart';

/// 돌려주는 값: 오류 문구(String?), 또는 (번호, 오류) 짝은 [번호, 오류] 목록, findLoginIds는 아이디 목록.
/// 이름이나 인자 모양이 틀리면 ArgumentError·TypeError를 던진다.
Object? runAction(AppStore s, String name, Map<String, Object?> a) {
  Role role() => Role.values.byName(a['role'] as String);
  String str(String k) => a[k] as String;
  int id(String k) => a[k] as int;
  const needLogin = '로그인이 필요합니다';

  switch (name) {
    case 'login':
      return s.login(role(), str('id'), str('password'));
    case 'socialLogin':
      s.socialLogin(role(), SocialProvider.values.byName(str('provider')));
      return null;
    case 'signup':
      return s.signup(
        role: role(),
        loginId: str('loginId'),
        name: str('name'),
        email: str('email'),
        password: str('password'),
        passwordConfirm: str('passwordConfirm'),
        termsAgreed: a['termsAgreed'] == true,
      );
    case 'logout':
      s.logout();
      return null;
    case 'withdraw':
      s.withdraw();
      return null;
    case 'findLoginIds':
      return s.findLoginIds(str('name'));
    case 'changePassword':
      return s.changePassword(str('current'), str('next'), str('confirm'));
    case 'updateProfile':
      if (s.me == null) return needLogin;
      return s.updateProfile(name: a['name'] as String?, email: a['email'] as String?, bio: a['bio'] as String?);
    case 'updateSettings':
      if (s.me == null) return needLogin;
      s.updateMe((m) {
        for (final MapEntry(:key, :value) in a.entries) {
          switch (key) {
            case 'profileImageUrl': m.profileImageUrl = value as String?;
            case 'notifySound': m.notifySound = value as String?;
            case 'notifyEnabled': m.notifyEnabled = value as bool;
            case 'notifyPreview': m.notifyPreview = value as bool;
            case 'notifyParking': m.notifyParking = value as bool;
            case 'notifyCrowd': m.notifyCrowd = value as bool;
            default: throw ArgumentError('바꿀 수 없는 설정: $key');
          }
        }
      });
      return null;
    case 'updateParking':
      return s.updateParking(id('eventId'), id('current'));
    case 'toggleFavorite':
      s.toggleFavorite(id('eventId'));
      return null;
    case 'scanQr':
      final (g, err) = s.scanQr(str('token'), source: VisitSource.values.byName(a['source'] as String? ?? 'qr'));
      return [g?.id, err];
    case 'markRead':
      final n = s.myNotifications().where((n) => n.id == id('id')).firstOrNull;
      if (n != null) s.markRead(n);
      return null;
    case 'saveEvent':
      final draft = eventFromJson(a['event'] as Map);
      // 개최자 번호는 보낸 값을 믿지 않고 로그인한 회원과 맞는지 본다
      if (s.me == null || draft.organizerId != s.me!.id) return [null, '개최자만 등록할 수 있습니다'];
      final err = s.saveEvent(draft);
      return [err == null ? draft.id : null, err];
    case 'deleteEvent':
      return s.deleteEvent(id('id'));
    case 'saveGuide':
      final (g, err) = s.saveGuide(
        guideId: id('guideId'),
        eventId: id('eventId'),
        name: str('name'),
        mapImageUrl: str('mapImageUrl'),
        program: str('program'),
        items: [for (final j in a['items'] as List) scheduleFromJson(j as Map)],
      );
      return [g?.id, err];
    case 'deleteGuide':
      return s.deleteGuide(id('id'));
    default:
      throw ArgumentError('없는 요청: $name');
  }
}
