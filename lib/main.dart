import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'screens/auth.dart';
import 'screens/organizer.dart';
import 'screens/participant.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreAutoLogin();
  runApp(const FestOnApp());
}

const _autoKey = 'auto_login';

/// 자동 로그인: 역할과 회원 ID만 기기에 남긴다.
/// shortcut: 서버가 없어 회원 ID를 그대로 둔다. 서버를 붙이면 만료되는 토큰을 보안 저장소에 둔다.
Future<void> restoreAutoLogin() async {
  try {
    final v = (await SharedPreferences.getInstance()).getString(_autoKey);
    if (v == null) return;
    final [role, id] = v.split(':');
    store.me = store.findMember(Role.values.byName(role), int.parse(id));
  } catch (_) {
    // 저장소를 못 쓰거나 값이 깨졌으면 로그인 화면부터 시작한다
  }
}

Future<void> saveAutoLogin(bool on) async {
  try {
    final p = await SharedPreferences.getInstance();
    final m = store.me;
    if (on && m != null) {
      await p.setString(_autoKey, '${m.role.name}:${m.id}');
    } else {
      await p.remove(_autoKey);
    }
  } catch (_) {}
}

/// 로그아웃·탈퇴 뒤 공통 처리: 쌓인 화면을 닫고 자동 로그인을 지운다.
void signOut(BuildContext context, {bool withdraw = false}) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  withdraw ? store.withdraw() : store.logout();
  saveAutoLogin(false);
}

class FestOnApp extends StatelessWidget {
  const FestOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fest-On',
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
