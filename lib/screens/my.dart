import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'organizer.dart';
import 'participant.dart';

/// 사진 고르기. 이미지가 아니거나 5MB를 넘으면 안내하고 null.
Future<String?> pickImage(BuildContext context) async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (f == null) return null;
  final name = f.name.toLowerCase();
  final okType = (f.mimeType?.startsWith('image/') ?? false) ||
      ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.heic'].any(name.endsWith);
  if (!okType) {
    if (context.mounted) toast(context, '이미지 파일만 첨부 가능합니다');
    return null;
  }
  final bytes = await f.readAsBytes();
  if (bytes.length > 5 * 1024 * 1024) {
    if (context.mounted) toast(context, '5MB 이하의 이미지만 올릴 수 있습니다');
    return null;
  }
  return store.addLocalImage(bytes);
}

class Avatar extends StatelessWidget {
  const Avatar(this.member, {super.key, this.radius = 44});
  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = member.profileImageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: brandSoft,
      child: ClipOval(
        child: SizedBox.expand(
          child: url == null ? const Padding(padding: EdgeInsets.all(12), child: AppIcon('my')) : NetImage(url),
        ),
      ),
    );
  }
}

/// 마이 화면의 설정 한 줄 (피그마: 왼쪽 아이콘 + 글자, 회색 띠)
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: const Color(0xFFEEF1F6),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: AppIcon(icon),
            title: Text(label, style: const TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );
}

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  static const _heading = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);

  Future<void> _logout(BuildContext context) async {
    if (await confirm(context, '로그아웃', '로그아웃 하시겠어요?', ok: '로그아웃') && context.mounted) signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final m = store.me;
          if (m == null) return const SizedBox();
          final isP = m.role == Role.participant;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  Avatar(m),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: IconButton.filledTonal(
                      tooltip: '프로필 사진 변경',
                      iconSize: 16,
                      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final url = await pickImage(context);
                        if (url != null) store.updateMe((m) => m.profileImageUrl = url);
                      },
                      icon: const Icon(Icons.camera_alt),
                    ),
                  ),
                ]),
                const SizedBox(width: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(isP ? (m.bio ?? '자기소개를 적어 보세요') : m.email, style: const TextStyle(color: muted)),
                    ]),
                  ),
                ),
                if (!isP) TextButton(onPressed: () => _logout(context), child: const Text('로그아웃')),
              ]),
              const Divider(height: 40, thickness: 1.5, color: ink),
              const Text('나의 축제', style: _heading),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: isP
                      ? _BigButton(
                          icon: 'favorite',
                          label: '관심 행사',
                          count: store.myFavoriteEvents().length,
                          onTap: () => push(context, const EventHistoryScreen(visits: false)))
                      : _BigButton(
                          icon: 'event',
                          label: '등록된 행사',
                          count: store.myEvents().length,
                          onTap: () => push(context, const OrgEventsScreen())),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isP
                      ? _BigButton(
                          icon: 'qr',
                          label: '방문 기록',
                          count: store.myVisits().length,
                          onTap: () => push(context, const EventHistoryScreen(visits: true)))
                      : _BigButton(
                          icon: 'guide',
                          label: '등록된 가이드',
                          count: store.myGuides().length,
                          onTap: () => push(context, const OrgGuidesScreen())),
                ),
              ]),
              const Divider(height: 40, thickness: 1.5, color: ink),
              const Text('개인정보 및 설정', style: _heading),
              const SizedBox(height: 14),
              SettingRow(icon: 'settings', label: '계정 설정', onTap: () => push(context, const AccountScreen())),
              // 알림 설정 컬럼은 참여자 테이블에만 있다
              if (isP) SettingRow(icon: 'bell', label: '알림 설정', onTap: () => push(context, const NotifySettingsScreen())),
            ],
          );
        },
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.count, required this.onTap});
  final String icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE3F0F7),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [
              AppIcon(icon, size: 40),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('$count', style: const TextStyle(color: brand, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

/// 관심 행사 목록 / 방문 기록 목록
class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key, required this.visits});
  final bool visits;

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  var _q = '';
  var _filter = StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          // 방문 기록은 (행사, 방문 시각) 쌍으로, 관심 행사는 행사만
          final rows = widget.visits
              ? [
                  for (final v in store.myVisits())
                    if (store.event(v.eventId) case final e?) (e, '방문 ${fmtDateTime(v.visitedAt)}')
                ]
              : [for (final e in store.myFavoriteEvents()) (e, null)];
          final q = _q.trim().toLowerCase();
          final list = rows
              .where((r) => _filter.test(r.$1) && (q.isEmpty || '${r.$1.name} ${r.$1.description}'.toLowerCase().contains(q)))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchField(hint: widget.visits ? '방문한 축제 검색' : '관심 행사 검색', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              FilterChips(
                values: const [StatusFilter.all, StatusFilter.upcoming, StatusFilter.ended],
                selected: _filter,
                label: (f) => f.label,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty) EmptyView(rows.isEmpty ? (widget.visits ? '방문 기록이 없습니다' : '관심 행사가 없습니다') : '검색 결과가 없습니다'),
              for (final (e, sub) in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventTile(
                    e,
                    subtitle: sub,
                    trailing: widget.visits ? null : FavoriteButton(e.id),
                    onTap: () => push(context, EventDetailScreen(eventId: e.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _edit(BuildContext context, String title, String initial, String? Function(String) save,
      {TextInputType? type, int? maxLength}) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, keyboardType: type, maxLength: maxLength),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('저장')),
        ],
      ),
    );
    if (v == null || !context.mounted) return;
    toast(context, save(v) ?? '변경되었습니다');
  }

  Widget _card(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(icon, color: ink),
            title: Text(title, style: const TextStyle(fontSize: 16)),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );

  Widget _bottomButton(String label, Color color, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            alignment: Alignment.centerLeft,
            foregroundColor: color,
            side: const BorderSide(color: Color(0xFFE6EAF2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final m = store.me;
          if (m == null) return const SizedBox();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('계정 정보'),
              _card(Icons.person_outline, '이름', m.name,
                  () => _edit(context, '이름 변경', m.name, (v) => store.updateProfile(name: v), maxLength: 50)),
              _card(Icons.mail_outline, '이메일', m.email,
                  () => _edit(context, '이메일 변경', m.email, (v) => store.updateProfile(email: v),
                      type: TextInputType.emailAddress, maxLength: 100)),
              // 마이 화면의 자기소개를 고칠 곳이 필요해 피그마에 없는 카드를 하나 더 둔다
              if (m.role == Role.participant)
                _card(Icons.edit_note, '자기소개', m.bio ?? '없음',
                    () => _edit(context, '자기소개 변경', m.bio ?? '', (v) => store.updateProfile(bio: v), maxLength: 200)),
              _card(
                  Icons.lock_outline,
                  '비밀번호 변경',
                  '계정 보안 관리',
                  () => m.passwordHash == null
                      ? toast(context, '소셜 로그인 계정은 비밀번호가 없습니다')
                      : push(context, const PasswordChangeScreen())),
              const SizedBox(height: 40),
              _bottomButton('로그아웃', Colors.red, () async {
                if (await confirm(context, '로그아웃', '로그아웃 하시겠어요?', ok: '로그아웃') && context.mounted) signOut(context);
              }),
              _bottomButton('회원 탈퇴', muted, () async {
                final ok = await confirm(
                  context,
                  '회원 탈퇴',
                  '탈퇴하면 관심 행사와 소셜 로그인 연결이 삭제되고 되돌릴 수 없습니다.\n방문 기록은 혼잡도 통계를 위해 남습니다.\n정말 탈퇴하시겠어요?',
                  ok: '탈퇴',
                );
                if (ok && context.mounted) signOut(context, withdraw: true);
              }),
            ],
          );
        },
      ),
    );
  }
}

/// 로그인류 화면 공통 머리: 큰 제목 + 회색 설명 (피그마)
class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.sub});
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: const TextStyle(color: muted)),
          ],
        ]),
      );
}

/// 입력칸 위의 작은 제목
Widget fieldLabel(String text) =>
    Padding(padding: const EdgeInsets.only(bottom: 8, top: 6), child: Text(text, style: const TextStyle(fontSize: 15)));

/// 아이콘 동그라미 + 두 줄 안내 (비밀번호 찾기·변경 화면 아래쪽)
class NoticeRow extends StatelessWidget {
  const NoticeRow({super.key, required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(radius: 22, backgroundColor: brandSoft, child: Icon(icon, color: brand)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            Text(sub, style: const TextStyle(color: muted)),
          ]),
        ),
      ]);
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _cur = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const PageHeading('비밀번호 변경', sub: '계정 보호를 위해 새 비밀번호를 설정해 주세요.'),
          fieldLabel('현재 비밀번호'),
          TextField(controller: _cur, obscureText: true, decoration: const InputDecoration(hintText: '현재 비밀번호를 입력해 주세요.')),
          const SizedBox(height: 14),
          fieldLabel('새 비밀번호'),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(hintText: '새 비밀번호를 입력해 주세요.', helperText: '영문, 숫자를 포함해 6~16자로 입력해 주세요'),
          ),
          const SizedBox(height: 14),
          fieldLabel('새 비밀번호 확인'),
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(hintText: '새 비밀번호를 다시 입력해 주세요.')),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              final err = store.changePassword(_cur.text, _next.text, _confirm.text);
              if (err != null) return toast(context, err);
              toast(context, '비밀번호가 변경되었습니다');
              Navigator.pop(context);
            },
            child: const Text('비밀번호 변경'),
          ),
          const SizedBox(height: 32),
          const NoticeRow(icon: Icons.priority_high, title: '다른 사이트에서 사용하지 않는', sub: '안전한 비밀번호를 사용해 주세요.'),
        ],
      ),
    );
  }
}

class NotifySettingsScreen extends StatelessWidget {
  const NotifySettingsScreen({super.key});

  static const sounds = ['기본', '종소리', '폭죽', '무음'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      backgroundColor: Colors.white,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final m = store.me;
          if (m == null) return const SizedBox();
          final on = m.notifyEnabled;
          Widget sw(String t, String s, bool v, void Function(Member, bool) set, {bool enabled = true}) => SwitchListTile(
                title: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text(s),
                value: v,
                onChanged: enabled ? (x) => store.updateMe((m) => set(m, x)) : null,
              );
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              sw('알림', '축제 푸시 알림을 받습니다.', on, (m, x) => m.notifyEnabled = x),
              ListTile(
                enabled: on,
                title: const Text('알림음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                trailing: DropdownButton<String>(
                  value: sounds.contains(m.notifySound) ? m.notifySound : '기본',
                  underline: const SizedBox(),
                  items: [for (final s in sounds) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: on ? (v) => store.updateMe((m) => m.notifySound = v) : null,
                ),
              ),
              sw('미리보기', '축제 푸시 알림이 왔을 때 메시지의 일부를 보여줍니다.', m.notifyPreview, (m, x) => m.notifyPreview = x,
                  enabled: on),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: const Color(0xFFEEF1F6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Text('실시간 상태 알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              sw('실시간 주차 상태 알림', '주차장의 여유 공간 상태를 실시간으로 알림 받습니다.', m.notifyParking,
                  (m, x) => m.notifyParking = x,
                  enabled: on),
              sw('현장 혼잡도 알림', '관심 축제 부스/스테이지 등 혼잡도가 바뀌면 실시간으로 알림 받습니다.', m.notifyCrowd,
                  (m, x) => m.notifyCrowd = x,
                  enabled: on),
            ],
          );
        },
      ),
    );
  }
}
