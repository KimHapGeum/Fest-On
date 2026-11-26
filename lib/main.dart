import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'screens/auth.dart';
import 'screens/organizer.dart';
import 'screens/participant.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreAutoLogin();
  startPolling();
  runApp(const FestOnApp());
}

const _autoKey = 'auto_login';

/// 자동 로그인: 서버를 쓰면 서버가 준 세션 값을, 서버 없이 쓰면 역할과 회원 ID만 기기에 남긴다.
/// shortcut: 세션 값을 일반 저장소에 둔다. 실제로 배포하면 만료되는 토큰을 보안 저장소에 둔다.
Future<void> restoreAutoLogin() async {
  try {
    final v = (await SharedPreferences.getInstance()).getString(_autoKey);
    if (online) {
      sessionToken = v;
      return await pull(); // 서버의 표와 로그인 상태를 받아 온다
    }
    if (v == null) return;
    final [role, id] = v.split(':');
    store.me = store.findMember(Role.values.byName(role), int.parse(id));
  } catch (_) {
    // 저장소를 못 쓰거나 값이 깨졌거나 서버가 꺼져 있으면 로그인 화면부터 시작한다 (서버는 5초마다 다시 묻는다)
  }
}

Future<void> saveAutoLogin(bool on) async {
  try {
    final p = await SharedPreferences.getInstance();
    final m = store.me;
    if (on && m != null) {
      await p.setString(_autoKey, online ? sessionToken! : '${m.role.name}:${m.id}');
    } else {
      await p.remove(_autoKey);
    }
  } catch (_) {}
}

/// 로그아웃·탈퇴 뒤 공통 처리: 쌓인 화면을 닫고 자동 로그인을 지운다.
void signOut(BuildContext context, {bool withdraw = false}) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  actErr(withdraw ? 'withdraw' : 'logout');
  saveAutoLogin(false);
}

class FestOnApp extends StatelessWidget {
  const FestOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '라두나',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final m = store.me;
          if (m == null) return const LoginScreen();
          // 회원이 바뀌면 탭 상태를 새로 만든다
          return m.role == Role.participant
              ? ParticipantShell(key: ValueKey('p${m.id}'))
              : OrganizerShell(key: ValueKey('o${m.id}'));
        },
      ),
    );
  }
}
