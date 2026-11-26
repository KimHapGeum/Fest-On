import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../api.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'my.dart';

/// 참여자/개최자 고르기. 피그마에는 없지만 정의서가 두 회원 테이블을 나눠서 필요하다.
class RolePicker extends StatelessWidget {
  const RolePicker({super.key, required this.role, required this.onChanged});
  final Role role;
  final ValueChanged<Role> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<Role>(
        segments: const [
          ButtonSegment(value: Role.participant, label: Text('참여자')),
          ButtonSegment(value: Role.organizer, label: Text('개최자')),
        ],
        selected: {role},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
      );
}

/// 네이버·카카오·애플·구글 동그라미 버튼 한 줄
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key, required this.onTap, this.verb = '로그인'});
  final ValueChanged<SocialProvider> onTap;
  final String verb;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final p in SocialProvider.values)
            Semantics(
              button: true,
              label: '${p.label}로 $verb',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onTap(p),
                child: Image.asset('assets/icons/btn_${p.name}.png', width: 56, height: 56),
              ),
            ),
        ],
      );
}

/// 가운데 글자가 있는 가는 선 ("또는 간편 가입")
Widget dividerText(String text) => Row(children: [
      const Expanded(child: Divider()),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(text, style: const TextStyle(color: muted))),
      const Expanded(child: Divider()),
    ]);

const _grey = Color(0xFFE4E7EC);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  var _role = Role.participant;
  var _auto = false;
  var _hidePw = true;

  Future<void> _login() async {
    if (_id.text.trim().isEmpty) return toast(context, '아이디(이메일)를 입력해 주세요.');
    if (_pw.text.isEmpty) return toast(context, '비밀번호를 입력해 주세요.');
    final err = await actErr('login', {'role': _role.name, 'id': _id.text, 'password': _pw.text});
    if (!mounted) return;
    if (err != null) return toast(context, err);
    saveAutoLogin(_auto);
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading('로그인'),
                  RolePicker(role: _role, onChanged: (r) => setState(() => _role = r)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _id,
                    decoration: const InputDecoration(hintText: '아이디 또는 이메일주소'),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pw,
                    obscureText: _hidePw,
                    onSubmitted: (_) => _login(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: '비밀번호(영문+숫자 6~16자)',
                      suffixIcon: IconButton(
                        tooltip: _hidePw ? '비밀번호 보기' : '비밀번호 숨기기',
                        icon: Icon(_hidePw ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hidePw = !_hidePw),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 피그마: 자동로그인 | 아이디 찾기 | 비밀번호 찾기 가 한 줄
                  Row(children: [
                    Checkbox(value: _auto, onChanged: (v) => setState(() => _auto = v ?? false)),
                    GestureDetector(
                        onTap: () => setState(() => _auto = !_auto), child: const Text('자동로그인')),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 6)),
                      onPressed: () => _push(const FindIdScreen()),
                      child: const Text('아이디 찾기'),
                    ),
                    const Text('|', style: TextStyle(color: muted)),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 6)),
                      onPressed: () => _push(const FindPwScreen()),
                      child: const Text('비밀번호 찾기'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _login, child: const Text('로그인')),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _grey, foregroundColor: ink),
                    onPressed: () => _push(SignupScreen(role: _role)),
                    child: const Text('회원가입'),
                  ),
                  const SizedBox(height: 24),
                  SocialButtons(onTap: (p) async {
                    final err = await actErr('socialLogin', {'role': _role.name, 'provider': p.name});
                    if (!context.mounted) return;
                    if (err != null) return toast(context, err);
                    saveAutoLogin(_auto);
                  }),
                  const SizedBox(height: 20),
                  const Text.rich(
                    TextSpan(style: TextStyle(color: muted, fontSize: 12), children: [
                      TextSpan(text: '회원가입 없이 이용 가능하며 첫 로그인시 '),
                      TextSpan(text: '이용 약관', style: TextStyle(color: brand)),
                      TextSpan(text: ' 및 '),
                      TextSpan(text: '개인정보처리방침', style: TextStyle(color: brand)),
                      TextSpan(text: ' 동의로 간주됩니다'),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text('시연 계정  참여자 user1 · 개최자 org1 / 비밀번호 pass1234',
                      textAlign: TextAlign.center, style: TextStyle(color: brand, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.role});
  final Role role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late var _role = widget.role;
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  var _terms = false;
  var _privacy = false;
  String? _pwError;
  String? _pw2Error;

  void _validatePw() => setState(() {
        _pwError = _pw.text.isEmpty ? null : AppStore.checkPassword(_pw.text);
        _pw2Error = _pw2.text.isEmpty || _pw.text == _pw2.text ? null : '비밀번호가 일치하지 않습니다';
      });

  Future<void> _alert(String msg) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
        ),
      );

  // shortcut: 약관 본문이 아직 없다. 확정되면 이 창에 본문을 넣는다.
  void _showTerms(String title) => _alert('$title\n\n약관 본문은 준비 중입니다.');

  Future<void> _submit() async {
    if (!_terms || !_privacy) return _alert('필수 약관에 모두 동의해주세요');
    final err = await actErr('signup', {
      'role': _role.name,
      'loginId': _id.text,
      'name': _name.text,
      'email': _email.text,
      'password': _pw.text,
      'passwordConfirm': _pw2.text,
      'termsAgreed': true,
    });
    if (!mounted) return;
    if (err != null) return toast(context, err);
    toast(context, '회원가입이 완료되었습니다. 로그인해 주세요');
    Navigator.pop(context);
  }

  Widget _agree(String label, bool value, ValueChanged<bool> onChanged) => Row(children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        Expanded(child: Text(label, style: const TextStyle(color: muted))),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: muted),
          onPressed: () => _showTerms(label),
          child: const Text('보기 >'),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const PageHeading('회원가입'),
          RolePicker(role: _role, onChanged: (r) => setState(() => _role = r)),
          const SizedBox(height: 14),
          TextField(controller: _id, decoration: const InputDecoration(hintText: '아이디')),
          const SizedBox(height: 10),
          // 피그마는 칸이 하나지만, 정의서의 이름·이메일이 필수라 따로 받는다
          TextField(
              controller: _name,
              decoration: InputDecoration(hintText: _role == Role.organizer ? '이름 또는 주최 기관명' : '이름')),
          const SizedBox(height: 10),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: '이메일주소')),
          const SizedBox(height: 10),
          TextField(
            controller: _pw,
            obscureText: true,
            onChanged: (_) => _validatePw(),
            decoration: InputDecoration(hintText: '비밀번호 (영문+숫자 6~16자)', errorText: _pwError),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pw2,
            obscureText: true,
            onChanged: (_) => _validatePw(),
            decoration: InputDecoration(hintText: '비밀번호 확인', errorText: _pw2Error),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Checkbox(value: _terms && _privacy, onChanged: (v) => setState(() => _terms = _privacy = v ?? false)),
            const Text('전체 동의', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ]),
          const Divider(),
          _agree('[필수] 이용약관 동의', _terms, (v) => setState(() => _terms = v)),
          _agree('[필수] 개인정보 처리방침 동의', _privacy, (v) => setState(() => _privacy = v)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('가입하기')),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('이미 계정이 있나요?', style: TextStyle(color: muted)),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: ink),
                onPressed: () => Navigator.pop(context),
                child: const Text('로그인')),
          ]),
          const SizedBox(height: 12),
          dividerText('또는 간편 가입'),
          const SizedBox(height: 16),
          SocialButtons(
            verb: '가입',
            onTap: (p) {
              Navigator.of(context).popUntil((r) => r.isFirst); // 로그인 화면 위에 쌓인 가입 화면을 닫는다
              actErr('socialLogin', {'role': _role.name, 'provider': p.name});
            },
          ),
        ],
      ),
    );
  }
}

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentCode;
  var _left = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send() {
    if (_name.text.trim().isEmpty) return toast(context, '이름을 입력해 주세요');
    if (_phone.text.trim().isEmpty) return toast(context, '휴대폰 번호를 입력해 주세요');
    if (!AppStore.isPhone(_phone.text)) return toast(context, '휴대폰 번호를 정확히 입력해 주세요.');
    // shortcut: 문자 발송 서비스가 없어 번호를 화면에 띄운다. 본인인증/SMS 서비스를 붙이면 이 부분을 바꾼다.
    _sentCode = (Random().nextInt(900000) + 100000).toString();
    toast(context, '[시연] 인증번호 $_sentCode 가 발송되었습니다');
    _timer?.cancel();
    setState(() => _left = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      setState(() => _left--);
    });
  }

  Future<void> _find() async {
    if (_sentCode == null) return toast(context, '인증번호를 먼저 받아 주세요');
    if (_left <= 0) return toast(context, '인증 시간이 만료되었습니다. 인증번호를 다시 받아주세요');
    if (_code.text.trim() != _sentCode) return toast(context, '인증번호가 일치하지 않습니다. 다시 확인해 주세요');
    final List<String> ids;
    try {
      ids = (await act('findLoginIds', {'name': _name.text}) as List).cast<String>();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
      return;
    }
    if (!mounted) return;
    _timer?.cancel();
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('아이디 찾기 결과'),
        content: Text(ids.isEmpty ? '일치하는 회원이 없습니다' : '가입된 아이디\n\n${ids.join('\n')}'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = '${two(max(0, _left) ~/ 60)}:${two(max(0, _left) % 60)}';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const PageHeading('아이디 찾기', sub: '가입할 때 등록한 정보로 아이디를 찾아드려요.'),
          fieldLabel('이름'),
          TextField(controller: _name, decoration: const InputDecoration(hintText: '이름을 입력해 주세요.')),
          const SizedBox(height: 18),
          fieldLabel('휴대폰 번호'),
          Row(children: [
            Expanded(
              child: TextField(
                  controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '휴대폰 번호')),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: _send,
              child: Text(_sentCode == null ? '인증번호 받기' : '다시 받기'),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            enabled: _sentCode != null,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(hintText: '인증번호 6자리', counterText: '', suffixText: _sentCode == null ? '03:00' : timer),
          ),
          const SizedBox(height: 8),
          const Text('인증번호가 오지 않나요? 번호를 확인하고 다시 시도해 주세요.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _find, child: const Text('아이디 찾기')),
          const SizedBox(height: 16),
          const Text('입력한 정보는 아이디 확인에만 사용돼요.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
          const Divider(height: 40),
          const Text('비밀번호가 기억나지 않나요?', textAlign: TextAlign.center, style: TextStyle(color: muted)),
          TextButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FindPwScreen())),
            child: const Text('비밀번호 찾기'),
          ),
        ],
      ),
    );
  }
}

class FindPwScreen extends StatefulWidget {
  const FindPwScreen({super.key});

  @override
  State<FindPwScreen> createState() => _FindPwScreenState();
}

class _FindPwScreenState extends State<FindPwScreen> {
  final _email = TextEditingController();
  var _sent = false;

  void _send() {
    if (_email.text.trim().isEmpty) return toast(context, '가입한 이메일 주소를 입력해 주세요');
    final e = AppStore.checkEmail(_email.text);
    if (e != null) return toast(context, e);
    // 계정이 있는지 드러내지 않게 결과는 늘 같다.
    // shortcut: 메일 서버가 없어 실제로 보내지 않는다. 서버를 붙이면 여기서 재설정 메일 API를 부른다.
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const PageHeading('비밀번호 찾기', sub: '가입한 이메일 주소로 재설정 링크를 보내드려요.'),
          fieldLabel('아이디 (이메일 주소)'),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: '가입한 이메일 주소를 입력해 주세요.')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _send, child: const Text('재설정 링크 받기')),
          const SizedBox(height: 24),
          if (_sent) ...[
            const NoticeRow(icon: Icons.check, title: '이메일을 확인해 주세요', sub: '메일이 오지 않으면 스팸함도 확인해 주세요.'),
            const SizedBox(height: 24),
          ],
          const Text('가입한 이메일 주소가 기억나지 않으신가요?', style: TextStyle(color: muted)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FindIdScreen())),
              child: const Text('아이디 찾기'),
            ),
          ),
          const Divider(height: 48),
          const Text('비밀번호 재설정 메일이 도착하지 않았나요?\n이메일 주소를 확인한 뒤 다시 요청해 주세요.',
              textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.6)),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _grey, foregroundColor: ink),
            onPressed: () => Navigator.pop(context),
            child: const Text('로그인으로 돌아가기'),
          ),
        ],
      ),
    );
  }
}
