import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'my.dart';
import 'participant.dart';

class OrganizerShell extends StatelessWidget {
  const OrganizerShell({super.key});

  @override
  Widget build(BuildContext context) => TabShell(tabs: [
        ('home', '홈', (_) => const HomeScreen(organizer: true)),
        ('event', '행사', (_) => const OrgEventsScreen()),
        ('guide', '가이드', (_) => const OrgGuidesScreen()),
        ('my', '마이', (_) => const MyScreen()),
      ]);
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 3),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// 주차 현재 대수 입력 (개최자 직접 입력)
Future<void> editParking(BuildContext context, Event e) async {
  final c = TextEditingController(text: store.snapshot(e.id).parkingCurrent?.toString() ?? '');
  c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length); // 새 값을 치면 기존 값이 바뀌게
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('현재 주차대수 입력'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(suffixText: '/ ${e.parkingTotal ?? '-'}대'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('저장')),
      ],
    ),
  );
  if (v == null || !context.mounted) return;
  final n = int.tryParse(v);
  if (n == null) return toast(context, '숫자를 입력해 주세요');
  toast(context, store.updateParking(e.id, n) ?? '주차 현황이 갱신되었습니다');
}

// ===================== 등록된 행사 =====================

class OrgEventsScreen extends StatefulWidget {
  const OrgEventsScreen({super.key});

  @override
  State<OrgEventsScreen> createState() => _OrgEventsScreenState();
}

class _OrgEventsScreenState extends State<OrgEventsScreen> {
  var _q = '';
  var _filter = StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final q = _q.trim().toLowerCase();
          final list = store
              .myEvents()
              .where((e) => _filter.test(e) && (q.isEmpty || '${e.name} ${e.description}'.toLowerCase().contains(q)))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchField(hint: '등록된 행사 검색', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              FilterChips(
                values: const [StatusFilter.all, StatusFilter.upcoming, StatusFilter.ended],
                selected: _filter,
                label: (f) => f.label,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty) const EmptyView('등록한 행사가 없습니다'),
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventTile(
                    e,
                    onTap: () => push(context, EventDetailScreen(eventId: e.id)),
                    trailing: PopupMenuButton<String>(
                      tooltip: '더보기',
                      onSelected: (v) async {
                        switch (v) {
                          case 'edit':
                            push(context, EventFormScreen(eventId: e.id));
                          case 'parking':
                            editParking(context, e);
                          case 'delete':
                            if (await confirm(context, '행사 삭제', '"${e.name}"을(를) 삭제할까요?\n참여자 화면에서 더 이상 보이지 않습니다.',
                                    ok: '삭제') &&
                                context.mounted) {
                              toast(context, store.deleteEvent(e.id) ?? '삭제되었습니다');
                            }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정')),
                        PopupMenuItem(value: 'parking', child: Text('주차 현황 입력')),
                        PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Center(
                child: IconButton.filledTonal(
                  tooltip: '행사 등록',
                  iconSize: 30,
                  onPressed: () => push(context, const EventFormScreen()),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===================== 행사 등록·수정 =====================

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.eventId});
  final int? eventId;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  late final Event? _old = widget.eventId == null ? null : store.event(widget.eventId!);
  late final _name = TextEditingController(text: _old?.name);
  late final _desc = TextEditingController(text: _old?.description);
  late final _visit = TextEditingController(text: _old?.visitInfo);
  late final _program = TextEditingController(text: _old?.program);
  late final _address = TextEditingController(text: _old?.address);
  late final _lat = TextEditingController(text: (_old?.latitude ?? 37.5665).toString());
  late final _lng = TextEditingController(text: (_old?.longitude ?? 126.9780).toString());
  late final _capacity = TextEditingController(text: _old?.capacity.toString());
  late final _parkingAt = TextEditingController(text: _old?.parkingLocation);
  late final _parkingTotal = TextEditingController(text: _old?.parkingTotal?.toString());
  late final _parkingNow =
      TextEditingController(text: _old == null ? '' : store.snapshot(_old.id).parkingCurrent?.toString() ?? '');
  late var _image = _old?.imageUrl ?? '';
  late var _status = _old?.status ?? EventStatus.ready;
  late var _region = _old?.region ?? AppStore.regions.first;
  late int? _cat = _old?.categoryId;
  late var _start = _old?.startAt ?? DateTime(store.now().year, store.now().month, store.now().day + 7, 10);
  late var _end = _old?.endAt ?? _start.add(const Duration(days: 2, hours: 8));

  /// 입력 중인 면수로 미리 보는 주차 혼잡도 (저장할 때 같은 식으로 계산된다)
  Level get _parkingPreview {
    final total = int.tryParse(_parkingTotal.text), now = int.tryParse(_parkingNow.text);
    if (total == null || now == null) return Level.unknown;
    return total == 0 ? Level.busy : AppStore.levelFromRatio(now / total);
  }

  void _save() {
    final lat = double.tryParse(_lat.text), lng = double.tryParse(_lng.text);
    final cap = int.tryParse(_capacity.text);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return toast(context, '위도·경도를 숫자로 바르게 입력해 주세요');
    if (cap == null) return toast(context, '수용 인원을 숫자로 입력해 주세요');
    if (_cat == null) return toast(context, '행사 종류를 골라 주세요');
    final draft = Event(
      id: _old?.id ?? 0,
      organizerId: store.me!.id,
      name: _name.text.trim(),
      imageUrl: _image,
      description: _desc.text.trim(),
      visitInfo: _visit.text.trim().isEmpty ? null : _visit.text.trim(),
      program: _program.text.trim().isEmpty ? null : _program.text.trim(),
      status: _status,
      startAt: _start,
      endAt: _end,
      region: _region,
      categoryId: _cat!,
      address: _address.text.trim(),
      latitude: lat,
      longitude: lng,
      capacity: cap,
      parkingLocation: _parkingAt.text.trim().isEmpty ? null : _parkingAt.text.trim(),
      parkingTotal: int.tryParse(_parkingTotal.text),
      createdAt: _old?.createdAt,
    );
    final err = store.saveEvent(draft);
    if (err != null) return toast(context, err);
    final now = int.tryParse(_parkingNow.text);
    if (now != null && draft.parkingTotal != null) store.updateParking(draft.id, now);
    toast(context, _old == null ? '행사가 성공적으로 등록되었습니다' : '행사 정보가 수정되었습니다');
    Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label,
          {int lines = 1, TextInputType? type, String? hint, bool required = false, ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 3,
          onChanged: onChanged,
          keyboardType: type ?? (lines > 1 ? TextInputType.multiline : null),
          decoration: InputDecoration(labelText: required ? '$label *' : label, hintText: hint, isDense: true),
        ),
      );

  Widget _box(String title, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFEEF1F6), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    const digits = TextInputType.number;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        centerTitle: true,
        title: Text(_old == null ? '행사 등록' : '행사 수정'),
      ),
      bottomNavigationBar: bottomAction('작성 완료', _save),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            button: true,
            label: '축제 대표 이미지 올리기',
            child: GestureDetector(
              onTap: () async {
                final url = await pickImage(context);
                if (url != null) setState(() => _image = url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    _image.isEmpty
                        ? Container(
                            color: const Color(0xFFD5DAE3),
                            alignment: Alignment.center,
                            child: const Text('축제 이미지 *', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          )
                        : NetImage(_image),
                    const Positioned(left: 12, top: 12, child: Icon(Icons.photo_camera, color: Colors.white, size: 30)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _box('축제 제목 및 설명', [
            _field(_name, '축제 제목', required: true),
            _field(_desc, '축제 설명', lines: 2, required: true),
          ]),
          DropdownButtonFormField<EventStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: '진행현황'),
            items: [for (final s in EventStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 12),
          // 피그마: 주차 현황과 현황 혼잡도 카드가 나란히 있다. 혼잡도는 정의서대로 입력값과 방문 수로 계산한다.
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      const Text('주차 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _field(_parkingAt, '주차장 위치'),
                      _field(_parkingTotal, '총 면수', type: digits, onChanged: (_) => setState(() {})),
                      _field(_parkingNow, '현재 대수', type: digits, onChanged: (_) => setState(() {})),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('혼잡도 ', style: TextStyle(color: muted)),
                        LevelChip(_parkingPreview),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      const Text('현황 혼잡도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _field(_capacity, '수용 인원', type: digits, required: true),
                      const Spacer(),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('혼잡도 ', style: TextStyle(color: muted)),
                        LevelChip(_old == null ? Level.unknown : store.crowdLevelOf(_old)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('QR 방문 수 ÷ 수용 인원으로\n자동 계산돼요',
                          textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _box('축제 통합 방문 안내 간략한 정보', [
            _field(_visit, '방문 안내', lines: 3, hint: '운영시간, 주차 안내, 셔틀버스 등'),
          ]),
          _box('기본 정보', [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await pickDateTime(context, _start);
                    if (t != null) setState(() => _start = t);
                  },
                  child: Text('시작\n${fmtDateTime(_start)}', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await pickDateTime(context, _end);
                    if (t != null) setState(() => _end = t);
                  },
                  child: Text('종료\n${fmtDateTime(_end)}', textAlign: TextAlign.center),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _region,
                  decoration: const InputDecoration(labelText: '지역 *', isDense: true),
                  items: [for (final r in AppStore.regions) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) => setState(() => _region = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _cat,
                  decoration: const InputDecoration(labelText: '종류 *', isDense: true),
                  items: [for (final c in store.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _cat = v),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _field(_address, '행사 주소', required: true),
            Row(children: [
              Expanded(child: _field(_lat, '위도', type: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 10),
              Expanded(child: _field(_lng, '경도', type: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            _field(_program, '진행 프로그램', lines: 2),
          ]),
        ],
      ),
    );
  }
}

// ===================== 가이드 =====================

class OrgGuidesScreen extends StatefulWidget {
  const OrgGuidesScreen({super.key});

  @override
  State<OrgGuidesScreen> createState() => _OrgGuidesScreenState();
}

class _OrgGuidesScreenState extends State<OrgGuidesScreen> {
  var _q = '';
  var _filter = StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final q = _q.trim().toLowerCase();
          final list = store.myGuides().where((g) {
            final e = store.event(g.eventId)!;
            return _filter.test(e) && (q.isEmpty || '${e.name} ${g.guideName}'.toLowerCase().contains(q));
          }).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchField(hint: '등록된 가이드 검색', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              FilterChips(
                values: const [StatusFilter.all, StatusFilter.upcoming, StatusFilter.ended],
                selected: _filter,
                label: (f) => f.label,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Text('등록된 가이드', style: TextStyle(color: muted, fontSize: 15))),
                Text('최신순', style: TextStyle(color: muted)),
              ]),
              const SizedBox(height: 10),
              if (list.isEmpty) const EmptyView('등록한 가이드가 없습니다'),
              for (final g in list)
                GuideCard(
                  g,
                  onTap: () => push(context, GuideFormScreen(guideId: g.id)),
                  trailing: IconButton(
                    tooltip: 'QR 보기',
                    onPressed: () => push(context, QrViewScreen(guideId: g.id)),
                    icon: const AppIcon('qr', size: 30),
                  ),
                ),
              Center(
                child: IconButton.filledTonal(
                  tooltip: '가이드 등록',
                  iconSize: 30,
                  onPressed: store.myEvents().isEmpty
                      ? () => toast(context, '행사를 먼저 등록해 주세요')
                      : () => push(context, const GuideFormScreen()),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GuideFormScreen extends StatefulWidget {
  const GuideFormScreen({super.key, this.guideId, this.eventId});
  final int? guideId;
  final int? eventId;

  @override
  State<GuideFormScreen> createState() => _GuideFormScreenState();
}

class _GuideFormScreenState extends State<GuideFormScreen> {
  late final EventGuide? _old = widget.guideId == null ? null : store.guide(widget.guideId!);
  late int? _eventId = _old?.eventId ?? widget.eventId ?? store.myEvents().firstOrNull?.id;
  late final _name = TextEditingController(text: _old?.guideName);
  late final _program = TextEditingController(text: _old?.program);
  late var _map = _old?.mapImageUrl ?? '';
  late final _items = [
    for (final s in _old == null ? <GuideSchedule>[] : store.schedulesOf(_old.id))
      GuideSchedule(title: s.title, startAt: s.startAt, endAt: s.endAt),
  ];
  final _titles = <GuideSchedule, TextEditingController>{};

  TextEditingController _titleOf(GuideSchedule s) => _titles.putIfAbsent(s, () => TextEditingController(text: s.title));

  void _addItem() {
    final e = _eventId == null ? null : store.event(_eventId!);
    final base = _items.isNotEmpty ? _items.last.endAt : (e?.startAt ?? store.now());
    setState(() => _items.add(GuideSchedule(title: '', startAt: base, endAt: base.add(const Duration(hours: 1)))));
  }

  void _save() {
    if (_eventId == null) return toast(context, '행사를 골라 주세요');
    for (final s in _items) {
      s.title = _titleOf(s).text;
    }
    final (g, err) = store.saveGuide(
      guideId: _old?.id ?? 0,
      eventId: _eventId!,
      name: _name.text,
      mapImageUrl: _map,
      program: _program.text,
      items: _items,
    );
    if (err != null) return toast(context, err);
    toast(context, _old == null ? '가이드가 등록되었습니다. QR 코드를 현장에 배포하세요' : '가이드가 수정되었습니다');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QrViewScreen(guideId: g!.id)));
  }

  static const _label = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

  @override
  Widget build(BuildContext context) {
    final events = store.myEvents();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        centerTitle: true,
        title: Text(_old == null ? '가이드 등록' : '가이드 수정'),
        actions: [
          if (_old != null)
            IconButton(
              tooltip: '가이드 삭제',
              onPressed: () async {
                if (await confirm(context, '가이드 삭제', '가이드와 일정, QR 코드가 삭제됩니다.', ok: '삭제') && context.mounted) {
                  toast(context, store.deleteGuide(_old.id) ?? '삭제되었습니다');
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: bottomAction(_old == null ? '가이드 등록' : '저장', _save),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('행사장 지도'),
          Semantics(
            button: true,
            label: '행사장 지도 등록',
            child: GestureDetector(
              onTap: () async {
                final url = await pickImage(context);
                if (url != null) setState(() => _map = url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _map.isEmpty
                      ? Container(
                          color: const Color(0xFFD5DAE3),
                          alignment: Alignment.center,
                          child: const Text('지도 등록 *', style: TextStyle(fontSize: 18)),
                        )
                      : NetImage(_map, label: '지도'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFEEF1F6), borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('행사 이름', style: _label),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: events.any((e) => e.id == _eventId) ? _eventId : null,
                isExpanded: true,
                decoration: const InputDecoration(hintText: '행사 선택'),
                items: [
                  for (final e in events) DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))
                ],
                onChanged: (v) => setState(() => _eventId = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: _name, decoration: const InputDecoration(hintText: '가이드 이름 (예: A구역 안내, 먹거리존)')),
              const SizedBox(height: 18),
              const Text('진행 프로그램', style: _label),
              const SizedBox(height: 8),
              TextField(
                controller: _program,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(hintText: '개막식, 전통 체험 부스, 야간 콘서트'),
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Text('스케줄', style: _label)),
                TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('일정 추가')),
              ]),
              if (_items.isEmpty) const Text('일정을 추가하면 참여자 가이드 화면에 시간표가 보여요', style: TextStyle(color: muted)),
              for (final s in _items)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextField(controller: _titleOf(s), decoration: const InputDecoration(hintText: '일정 제목 (예: 개막식)')),
                        ),
                        IconButton(
                          tooltip: '일정 삭제',
                          onPressed: () => setState(() => _items.remove(s)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ]),
                      Row(children: [
                        TextButton(
                          onPressed: () async {
                            final t = await pickDateTime(context, s.startAt);
                            if (t != null) setState(() => s.startAt = t);
                          },
                          child: Text(fmtDateTime(s.startAt)),
                        ),
                        const Text('~'),
                        TextButton(
                          onPressed: () async {
                            final t = await pickDateTime(context, s.endAt);
                            if (t != null) setState(() => s.endAt = t);
                          },
                          child: Text(fmtDateTime(s.endAt)),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// QR 생성·공유: 화면에 띄워 인쇄하거나 값을 복사한다.
class QrViewScreen extends StatelessWidget {
  const QrViewScreen({super.key, required this.guideId});
  final int guideId;

  @override
  Widget build(BuildContext context) {
    final g = store.guide(guideId);
    final e = g == null ? null : store.event(g.eventId);
    return Scaffold(
      appBar: festBar(context, title: 'QR 코드'),
      body: g == null || e == null
          ? const EmptyView('삭제된 가이드입니다')
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(e.name, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                Text(g.guideName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6EAF2)),
                    ),
                    child: QrImageView(data: g.qrToken, size: 240, semanticsLabel: '${g.guideName} QR 코드'),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(g.qrToken, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: g.qrToken));
                    toast(context, 'QR 값을 복사했습니다');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('QR 값 복사 (공유)'),
                ),
                const SizedBox(height: 8),
                const Text('이 QR 코드를 행사장에 붙여 두면 참여자가 스캔해 방문을 남기고 가이드를 볼 수 있어요.',
                    textAlign: TextAlign.center, style: TextStyle(color: muted)),
              ],
            ),
    );
  }
}
