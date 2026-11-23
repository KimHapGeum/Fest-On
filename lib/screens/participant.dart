import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'my.dart';
import 'organizer.dart';

/// 하단 탭 + 탭마다 자기 화면 스택. 상세 화면에서도 탭바가 보인다.
class TabShell extends StatefulWidget {
  const TabShell({super.key, required this.tabs});
  final List<(String icon, String label, Widget Function(ValueNotifier<int> current) page)> tabs;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  final current = ValueNotifier(0);
  late final _navs = List.generate(widget.tabs.length, (_) => GlobalKey<NavigatorState>());

  void _select(int i) {
    if (i == current.value) _navs[i].currentState?.popUntil((r) => r.isFirst);
    setState(() => current.value = i);
  }

  void _home() {
    _navs[0].currentState?.popUntil((r) => r.isFirst);
    setState(() => current.value = 0);
  }

  @override
  Widget build(BuildContext context) {
    return HomeJump(
      jump: _home,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _navs[current.value].currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else if (current.value != 0) {
            _home();
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: current.value,
            children: [
              for (var i = 0; i < widget.tabs.length; i++)
                Navigator(
                  key: _navs[i],
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => widget.tabs[i].$3(current)),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: current.value,
            onDestinationSelected: _select,
            backgroundColor: Colors.white,
            indicatorColor: brandSoft,
            height: 84,
            destinations: [
              for (final t in widget.tabs)
                NavigationDestination(
                  icon: Opacity(opacity: 0.55, child: AppIcon(t.$1, size: 38)),
                  selectedIcon: AppIcon(t.$1, size: 40),
                  label: t.$2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParticipantShell extends StatelessWidget {
  const ParticipantShell({super.key});

  @override
  Widget build(BuildContext context) => TabShell(
    tabs: [
      ('home', '홈', (_) => const HomeScreen()),
      ('map', '지도', (_) => const MapScreen()),
      ('list', '목록', (_) => const EventListScreen()),
      ('qr', 'QR', (cur) => QrScreen(current: cur, tabIndex: 3)),
      ('my', '마이', (_) => const MyScreen()),
    ],
  );
}

Future<T?> push<T>(BuildContext context, Widget w) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => w));

// shortcut: 위치 권한·GPS 없이 사용자가 고른 지역의 대표 좌표를 현위치로 쓴다. geolocator를 붙이면 실제 좌표를 첫 값으로 넣는다.
class Place {
  const Place(this.region, this.area, this.point);
  final String region; // 행사 지역 값(event.region)과 같은 시·도 이름. 홈 지역 필터가 이 값을 쓴다
  final String area;
  final LatLng point;
  String get name => '$region $area';
}

/// 지역선택(시·도) → 세부선택(시·군·구)과 대표 좌표. 시·도 순서는 AppStore.regions와 같다.
const placeTree = <String, List<(String, LatLng)>>{
  '서울': [
    ('중구', LatLng(37.5665, 126.9780)),
    ('종로구', LatLng(37.5735, 126.9790)),
    ('강남구', LatLng(37.4979, 127.0276)),
    ('마포구', LatLng(37.5563, 126.9236)),
    ('영등포구', LatLng(37.5264, 126.8962)),
    ('송파구', LatLng(37.5145, 127.1059)),
  ],
  '경기': [
    ('수원시', LatLng(37.2636, 127.0286)),
    ('성남시', LatLng(37.4200, 127.1267)),
    ('고양시', LatLng(37.6584, 126.8320)),
    ('용인시', LatLng(37.2411, 127.1776)),
  ],
  '인천': [('중구', LatLng(37.4738, 126.6216)), ('연수구', LatLng(37.4100, 126.6783)), ('부평구', LatLng(37.5070, 126.7219))],
  '강원': [('춘천시', LatLng(37.8813, 127.7298)), ('강릉시', LatLng(37.7519, 128.8761)), ('속초시', LatLng(38.2070, 128.5918))],
  '충청': [('대전', LatLng(36.3504, 127.3845)), ('청주시', LatLng(36.6424, 127.4890)), ('천안시', LatLng(36.8151, 127.1139))],
  '전라': [('전주시', LatLng(35.8242, 127.1480)), ('광주', LatLng(35.1595, 126.8526)), ('여수시', LatLng(34.7604, 127.6622))],
  '경상': [('대구', LatLng(35.8714, 128.6014)), ('경주시', LatLng(35.8562, 129.2247)), ('포항시', LatLng(36.0190, 129.3435))],
  '부산': [('해운대구', LatLng(35.1631, 129.1635)), ('중구', LatLng(35.1064, 129.0323)), ('수영구', LatLng(35.1455, 129.1131))],
  '제주': [('제주시', LatLng(33.4996, 126.5312)), ('서귀포시', LatLng(33.2541, 126.5600))],
};

/// 지금 고른 지역. 상단바 지역 버튼으로 바꾸고, 지도 중심·"내 주변" 거리·홈 지역 필터가 이 값을 따른다.
final currentPlace = ValueNotifier(const Place('서울', '중구', LatLng(37.5665, 126.9780)));

Widget _sheetHead(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
  child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
);

/// 왼쪽에서 시·도(지역선택), 오른쪽에서 시·군·구(세부선택)를 고른다.
Future<void> pickPlace(BuildContext context) async {
  var region = currentPlace.value.region;
  final picked = await showModalBottomSheet<Place>(
    context: context,
    useRootNavigator: true, // 탭 안이 아니라 맨 위에 띄워 하단바에 가려지지 않게
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SizedBox(
      height: MediaQuery.sizeOf(c).height * 0.6,
      child: SafeArea(
        child: StatefulBuilder(
          builder: (c, setSheet) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHead('지역선택'),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in placeTree.keys)
                            ListTile(
                              title: Text(r),
                              selected: r == region,
                              selectedColor: brand,
                              selectedTileColor: brandSoft,
                              onTap: () => setSheet(() => region = r),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHead('세부선택'),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final (area, point) in placeTree[region]!)
                            Builder(
                              builder: (_) {
                                final here = Place(region, area, point);
                                final on = here.name == currentPlace.value.name;
                                return ListTile(
                                  title: Text(area, style: TextStyle(color: on ? brand : null)),
                                  trailing: on ? const Icon(Icons.check, color: brand) : null,
                                  onTap: () => Navigator.pop(c, here),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked != null) currentPlace.value = picked;
}

class PlaceButton extends StatelessWidget {
  const PlaceButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: currentPlace,
    builder: (context, place, _) => Semantics(
      button: true,
      label: '현위치 ${place.name}, 눌러서 지역 변경',
      child: Material(
        color: brandSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => pickPlace(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.place, color: brand, size: 16),
                const SizedBox(width: 2),
                Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 피그마 공통 상단 바: 앱 이름(로고) · 현위치 · 알림. 알림은 참여자만 있다.
PreferredSizeWidget festBar(
  BuildContext context, {
  String? title,
  bool location = false,
  List<Widget> actions = const [],
}) => AppBar(
  titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
  title: Row(
    children: [
      const LogoTitle(),
      if (title != null) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ],
  ),
  actions: [
    ...actions,
    if (location) const PlaceButton(),
    if (store.me?.role == Role.participant) const BellButton(),
    const SizedBox(width: 6),
  ],
);

class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => IconButton(
      tooltip: '알림',
      onPressed: () => push(context, const NotificationsScreen()),
      icon: Badge(
        isLabelVisible: store.unreadCount > 0,
        label: Text('${store.unreadCount}'),
        child: const AppIcon('bell', size: 28),
      ),
    ),
  );
}

/// 화면 안 큰 제목 (피그마의 "추천 행사", "내 주변" 등)
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
  );
}

// ===================== 홈 (참여자·개최자 공통) =====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.organizer = false});
  final bool organizer;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _sort = '최신순';
  // 상단바 지역의 시·도를 따라간다. 필터 버튼으로 "전체 지역"이나 다른 시·도를 잠깐 볼 수는 있다.
  String? _region = currentPlace.value.region;
  final _page = PageController();
  var _bannerIndex = 0;

  void _followPlace() => setState(() => _region = currentPlace.value.region);

  @override
  void initState() {
    super.initState();
    currentPlace.addListener(_followPlace);
  }

  @override
  void dispose() {
    currentPlace.removeListener(_followPlace);
    _page.dispose();
    super.dispose();
  }

  Widget _sortButton(String label) => Expanded(
    child: ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: _sort == label,
      showCheckmark: false,
      onSelected: (_) => setState(() => _sort = label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context, location: true),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final source = widget.organizer ? store.myEvents() : store.liveEvents;
          // 배너: 고른 지역의 인기 행사. 그 지역에 진행·예정 행사가 없으면 전체 인기 행사
          List<Event> popular(String? region) => store
              .searchEvents(sort: '관심순', region: region, source: source)
              .where((e) => store.statusOf(e) != EventStatus.ended)
              .take(5)
              .toList();
          final local = popular(_region);
          final banners = local.isNotEmpty ? local : popular(null);
          final list = store.searchEvents(sort: _sort, region: _region, source: source);
          return Column(
            children: [
              // 피그마: 최신순 · 관심순 · 지역 버튼이 배너 위에 있다
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    _sortButton('최신순'),
                    const SizedBox(width: 10),
                    _sortButton('관심순'),
                    const SizedBox(width: 10),
                    Expanded(
                      // 값이 null인 메뉴는 Flutter가 "선택 안 함"으로 보고 onSelected를 부르지 않아, 전체 지역은 ''로 받는다
                      child: PopupMenuButton<String>(
                        tooltip: '지역',
                        onSelected: (v) => setState(() => _region = v.isEmpty ? null : v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: '', child: Text('전체 지역')),
                          for (final r in AppStore.regions) PopupMenuItem(value: r, child: Text(r)),
                        ],
                        child: Chip(
                          backgroundColor: _region == null ? Colors.white : brandSoft,
                          label: SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Text(_region ?? '지역'), const Icon(Icons.expand_more, size: 18)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (banners.isNotEmpty) _banner(banners),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(widget.organizer ? '등록된 행사' : '추천 행사'),
                          if (list.isEmpty) EmptyView(widget.organizer ? '등록한 행사가 없습니다' : '조건에 맞는 행사가 없습니다'),
                          for (final e in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: EventTile(e, onTap: () => push(context, EventDetailScreen(eventId: e.id))),
                            ),
                          if (widget.organizer)
                            OutlinedButton.icon(
                              onPressed: () => push(context, const EventFormScreen()),
                              icon: const Icon(Icons.add),
                              label: const Text('행사 등록'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _banner(List<Event> banners) {
    final i = _bannerIndex.clamp(0, banners.length - 1);
    void go(int d) => _page.animateToPage(
      (i + d) % banners.length,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          PageView(
            controller: _page,
            onPageChanged: (v) => setState(() => _bannerIndex = v),
            children: [
              for (final e in banners)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(e.imageUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black45, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(store.statusOf(e)),
                          const SizedBox(height: 6),
                          Text(
                            e.name,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          Text(fmtRange(e.startAt, e.endAt), style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(200, 44), shape: const StadiumBorder()),
                          onPressed: () => push(context, EventDetailScreen(eventId: e.id)),
                          child: const Text('자세히 보기'),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (banners.length > 1) ...[
            Align(
              alignment: const Alignment(-1, 0.25),
              child: IconButton(
                tooltip: '이전 배너',
                color: Colors.white,
                onPressed: () => go(-1),
                icon: const Icon(Icons.chevron_left, size: 36),
              ),
            ),
            Align(
              alignment: const Alignment(1, 0.25),
              child: IconButton(
                tooltip: '다음 배너',
                color: Colors.white,
                onPressed: () => go(1),
                icon: const Icon(Icons.chevron_right, size: 36),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== 지도 =====================

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _dist = Distance();
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    currentPlace.addListener(_recenter);
  }

  @override
  void dispose() {
    currentPlace.removeListener(_recenter);
    super.dispose();
  }

  void _recenter() => _map.move(currentPlace.value.point, 12.5);

  void _zoom(double d) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + d).clamp(3, 18).toDouble());
  }

  Widget _mapButton(IconData icon, String tip, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FloatingActionButton.small(
      heroTag: tip,
      tooltip: tip,
      backgroundColor: Colors.white,
      foregroundColor: ink,
      onPressed: onTap,
      child: Icon(icon),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context, location: true),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, currentPlace]),
        builder: (context, _) {
          final here = currentPlace.value.point;
          final list = store.liveEvents.where((e) => store.statusOf(e) != EventStatus.ended).toList();
          double km(Event e) => _dist.as(LengthUnit.Meter, here, LatLng(e.latitude, e.longitude)) / 1000;
          list.sort((a, b) => km(a).compareTo(km(b)));
          return Column(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.42,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: here,
                        initialZoom: 12.5,
                        minZoom: 3,
                        maxZoom: 18,
                        // 두 손가락 벌리기·오므리기, 두 번 탭, 마우스 휠 확대를 모두 켠다
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.feston.fest_on',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: here,
                              width: 22,
                              height: 22,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: brand,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 3)),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                              ),
                            ),
                            for (final e in list)
                              Marker(
                                point: LatLng(e.latitude, e.longitude),
                                width: 44,
                                height: 44,
                                alignment: Alignment.topCenter,
                                child: Tooltip(
                                  message: e.name,
                                  child: GestureDetector(
                                    onTap: () => push(context, EventDetailScreen(eventId: e.id)),
                                    child: const AppIcon('event', size: 40),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // OSM 이용 조건상 출처 표기는 지우지 않고 작게만 둔다
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: ColoredBox(
                            color: Color(0xB3FFFFFF),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9, color: ink)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Column(
                        children: [
                          _mapButton(Icons.add, '확대', () => _zoom(1)),
                          _mapButton(Icons.remove, '축소', () => _zoom(-1)),
                          _mapButton(Icons.my_location, '현위치로', _recenter),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    const SectionTitle('내 주변'),
                    for (final e in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EventTile(
                          e,
                          subtitle: '${km(e).toStringAsFixed(1)}km · ${e.address}',
                          onTap: () => push(context, EventDetailScreen(eventId: e.id)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===================== 행사 목록 =====================

class FavoriteButton extends StatelessWidget {
  const FavoriteButton(this.eventId, {super.key});
  final int eventId;

  @override
  Widget build(BuildContext context) {
    final on = store.isFavorite(eventId);
    return IconButton(
      tooltip: on ? '관심 행사 해제' : '관심 행사 등록',
      onPressed: () => store.toggleFavorite(eventId),
      icon: Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        color: on ? const Color(0xFFFFB400) : muted,
        size: 30,
      ),
    );
  }
}

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  var _q = '';
  String? _region;
  int? _cat;
  DateTimeRange? _range;
  var _sort = '최신순';

  Future<void> _pickRange() async {
    final now = store.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Widget _menu<T>(String label, T? value, List<(T?, String)> items, ValueChanged<T?> onPick) {
    final active = value != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<(T?, String)>(
        tooltip: label,
        onSelected: (v) => onPick(v.$1),
        itemBuilder: (_) => [for (final it in items) PopupMenuItem(value: it, child: Text(it.$2))],
        child: Chip(
          label: Text(active ? items.firstWhere((it) => it.$1 == value).$2 : label),
          avatar: const Icon(Icons.arrow_drop_down, size: 18),
          backgroundColor: active ? brandSoft : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context, location: true),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.searchEvents(
            query: _q,
            region: _region,
            categoryId: _cat,
            from: _range?.start,
            to: _range?.end,
            sort: _sort,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchField(hint: '축제 및 행사 검색', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 16),
              const Text('필터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _menu<String>('지역', _region, [
                      (null, '전체 지역'),
                      for (final r in AppStore.regions) (r, r),
                    ], (v) => setState(() => _region = v)),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(_range == null ? '날짜' : fmtRange(_range!.start, _range!.end)),
                        avatar: const Icon(Icons.calendar_month, size: 18),
                        backgroundColor: _range == null ? Colors.white : brandSoft,
                        onPressed: _pickRange,
                        onDeleted: _range == null ? null : () => setState(() => _range = null),
                      ),
                    ),
                    _menu<int>('종류', _cat, [
                      (null, '전체 종류'),
                      for (final c in store.categories) (c.id, c.name),
                    ], (v) => setState(() => _cat = v)),
                    _menu<String>('정렬', _sort, const [
                      ('최신순', '최신순'),
                      ('마감임박순', '마감임박순'),
                      ('인기순', '인기순'),
                    ], (v) => setState(() => _sort = v ?? '최신순')),
                  ],
                ),
              ),
              const Divider(height: 28, thickness: 1.5, color: ink),
              Text('검색결과 ${list.length}건', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (list.isEmpty) const EmptyView('검색 결과가 없습니다'),
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventTile(
                    e,
                    trailing: FavoriteButton(e.id),
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

// ===================== 행사 상세 (참여자·개최자 공통) =====================

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.child, this.trailing, this.center = false});
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

/// 맨 아래 고정 버튼 (피그마의 "행사 가이드 확인", "QR 생성 및 공유하기", "작성 완료")
Widget bottomAction(String label, VoidCallback onPressed, {Widget? icon}) => SafeArea(
  top: false,
  child: Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(onPressed: onPressed, icon: icon, label: Text(label)),
  ),
);

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final int eventId;

  /// 개최자: 이 행사의 가이드 QR을 고르거나 새 가이드를 만든다.
  void _qrSheet(BuildContext context, Event e) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('QR을 만들 가이드를 고르세요', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final g in store.guidesOf(e.id))
            ListTile(
              leading: const AppIcon('qr'),
              title: Text(g.guideName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(c);
                push(context, QrViewScreen(guideId: g.id));
              },
            ),
          ListTile(
            leading: const Icon(Icons.add, color: brand),
            title: const Text('새 가이드 등록', style: TextStyle(color: brand)),
            onTap: () {
              Navigator.pop(c);
              push(context, GuideFormScreen(eventId: e.id));
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final e = store.event(eventId);
        if (e == null) {
          return Scaffold(appBar: festBar(context), body: const EmptyView('삭제되었거나 없는 행사입니다'));
        }
        final status = store.statusOf(e);
        final ratio = store.parkingFreeRatio(e);
        final parking = store.parkingLevelOf(e), crowd = store.crowdLevelOf(e);
        final isParticipant = store.me?.role == Role.participant;
        final isOwner = store.me?.role == Role.organizer && e.organizerId == store.me?.id;
        return Scaffold(
          appBar: festBar(
            context,
            location: true,
            actions: [
              if (isParticipant) FavoriteButton(e.id),
              if (isOwner)
                IconButton(
                  tooltip: '행사 수정',
                  onPressed: () => push(context, EventFormScreen(eventId: e.id)),
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          bottomNavigationBar: isOwner
              ? bottomAction('QR 생성 및 공유하기', () => _qrSheet(context, e), icon: const AppIcon('qr', size: 24))
              : bottomAction(
                  '행사 가이드 확인',
                  () => push(context, GuideListScreen(eventId: e.id)),
                  icon: const AppIcon('guide', size: 24),
                ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(e.imageUrl)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.region} · ${store.category(e.categoryId)?.name ?? ''}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 4),
                      Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(e.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                      const SizedBox(height: 8),
                      _line(Icons.event, '${fmtDateTime(e.startAt)} ~ ${fmtDateTime(e.endAt)}'),
                      _line(Icons.place, e.address),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: StatusBadge(status)),
              const SizedBox(height: 10),
              // 피그마: 주차 현황과 현황 혼잡도 카드가 나란히 있다
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: InfoCard(
                        title: '주차 현황',
                        center: true,
                        child: Column(
                          children: [
                            Text(
                              e.parkingLocation ?? '주차 정보 없음',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ratio == null ? '미확인' : '[${parking.label}]',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: levelColor(parking)),
                            ),
                            if (ratio != null)
                              Text('여유 ${(ratio * 100).round()}%', style: const TextStyle(color: muted, fontSize: 13)),
                            if (isOwner && e.parkingTotal != null)
                              TextButton(onPressed: () => editParking(context, e), child: const Text('주차 입력')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InfoCard(
                        title: '현황 혼잡도',
                        center: true,
                        child: Column(
                          children: [
                            Text(
                              crowd == Level.unknown ? '미확인' : '[${crowd.label}]',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: levelColor(crowd)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status == EventStatus.ongoing ? '최근 1시간 방문 기준' : '진행 중일 때만 보여요',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              InfoCard(
                title: '축제 통합 방문 안내',
                child: Text(
                  e.visitInfo?.isNotEmpty == true ? e.visitInfo! : '등록된 안내가 없습니다',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              if (e.program?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                InfoCard(
                  title: '진행 프로그램',
                  child: Text(e.program!, style: const TextStyle(height: 1.5)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: brand),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(color: ink)),
        ),
      ],
    ),
  );
}

// ===================== 가이드 =====================

/// 피그마 가이드 카드: 위에 지도 썸네일 + 행사명, 선 아래 가이드명 >
class GuideCard extends StatelessWidget {
  const GuideCard(this.guide, {super.key, this.onTap, this.trailing});
  final EventGuide guide;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final e = store.event(guide.eventId)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(width: 110, height: 64, child: NetImage(guide.mapImageUrl, label: '지도')),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2),
                          const SizedBox(height: 4),
                          StatusBadge(store.statusOf(e)),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(guide.guideName, style: const TextStyle(color: muted, fontSize: 15)),
                    ),
                    const Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuideListScreen extends StatefulWidget {
  const GuideListScreen({super.key, this.eventId});
  final int? eventId;

  @override
  State<GuideListScreen> createState() => _GuideListScreenState();
}

class _GuideListScreenState extends State<GuideListScreen> {
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
          final list = store.guides.where((g) {
            final e = store.event(g.eventId);
            if (e == null) return false;
            if (widget.eventId != null && g.eventId != widget.eventId) return false;
            if (!_filter.test(e)) return false;
            return q.isEmpty || '${e.name} ${g.guideName} ${g.program}'.toLowerCase().contains(q);
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchField(hint: '행사명, 프로그램 검색', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              FilterChips(
                values: StatusFilter.values,
                selected: _filter,
                label: (f) => f.label,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: Text('참여 가능한 가이드', style: TextStyle(color: muted, fontSize: 15)),
                  ),
                  Text('최신순', style: TextStyle(color: muted)),
                ],
              ),
              const SizedBox(height: 10),
              if (list.isEmpty) EmptyView(q.isEmpty ? '등록된 가이드가 없습니다' : '검색 결과가 없습니다'),
              for (final g in list) GuideCard(g, onTap: () => push(context, GuideDetailScreen(guideId: g.id))),
            ],
          );
        },
      ),
    );
  }
}

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guideId});
  final int guideId;

  void _zoom(BuildContext context, String url) => showDialog<void>(
    context: context,
    builder: (c) => Dialog.fullscreen(
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: NetImage(url, label: '지도', fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(tooltip: '닫기', onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),
          ),
        ],
      ),
    ),
  );

  static const _label = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final g = store.guide(guideId);
        final e = g == null ? null : store.event(g.eventId);
        if (g == null || e == null) {
          return Scaffold(appBar: festBar(context), body: const EmptyView('삭제되었거나 없는 가이드입니다'));
        }
        final now = store.now();
        final items = store.schedulesOf(g.id);
        return Scaffold(
          appBar: festBar(context),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('행사장 지도'),
              Semantics(
                button: true,
                label: '행사장 지도 크게 보기',
                child: GestureDetector(
                  onTap: () => _zoom(context, g.mapImageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetImage(g.mapImageUrl, label: '지도'),
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: Chip(avatar: Icon(Icons.zoom_in, size: 18), label: Text('확대')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFEEF1F6), borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('행사 이름', style: _label),
                    const SizedBox(height: 4),
                    Text('${e.name} · ${g.guideName}'),
                    const SizedBox(height: 18),
                    const Text('진행 프로그램', style: _label),
                    const SizedBox(height: 4),
                    Text(g.program, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 18),
                    const Text('스케줄', style: _label),
                    const SizedBox(height: 6),
                    if (items.isEmpty) const Text('등록된 일정이 없습니다', style: TextStyle(color: muted)),
                    for (final s in items)
                      Builder(
                        builder: (_) {
                          final live = !now.isBefore(s.startAt) && now.isBefore(s.endAt);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: live ? brandSoft : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${fmtTime(s.startAt)} ~ ${fmtTime(s.endAt)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: brand),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(s.title)),
                                if (live)
                                  const Text(
                                    '진행중',
                                    style: TextStyle(color: brand, fontWeight: FontWeight.w800),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================== QR =====================

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.current, required this.tabIndex});
  final ValueNotifier<int> current;
  final int tabIndex;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  var _busy = false;
  DateTime _lastFail = DateTime(2000);

  void _handle(String? raw, VisitSource source) {
    if (raw == null || raw.isEmpty || _busy) return;
    final (g, err) = store.scanQr(raw, source: source);
    if (err != null) {
      // 같은 잘못된 코드를 계속 비추면 알림이 쌓이지 않게 2초에 한 번만 띄운다
      if (DateTime.now().difference(_lastFail) > const Duration(seconds: 2)) {
        _lastFail = DateTime.now();
        toast(context, err);
      }
      return;
    }
    _busy = true;
    toast(context, '방문이 기록되었습니다');
    push(context, GuideDetailScreen(guideId: g!.id)).then((_) => _busy = false);
  }

  Future<void> _manual() async {
    final c = TextEditingController();
    final sample = store.guides.where((g) => store.event(g.eventId) != null).firstOrNull?.qrToken;
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR 값 직접 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'QR 코드 아래의 값'),
            ),
            if (sample != null) ...[
              const SizedBox(height: 8),
              Text('시연용 값: $sample', style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('확인')),
        ],
      ),
    );
    if (mounted) _handle(v?.trim(), VisitSource.manual);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ValueListenableBuilder(
        valueListenable: widget.current,
        builder: (context, cur, _) {
          // 다른 탭에 있거나 가이드 화면이 위에 있으면 카메라를 끈다
          final on = cur == widget.tabIndex && (ModalRoute.of(context)?.isCurrent ?? true);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.qr_code_scanner, size: 36, color: muted),
              const SizedBox(height: 8),
              const Text(
                '축제 QR 코드를 스캔하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '현장에 설치된 QR 코드를 인식하면\n방문이 기록되고 축제 가이드를 이용할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              AspectRatio(
                aspectRatio: 1.2,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFBFC6D4)),
                  ),
                  child: on
                      ? MobileScanner(
                          onDetect: (cap) => _handle(cap.barcodes.firstOrNull?.rawValue, VisitSource.qr),
                          errorBuilder: (context, error) => const _CameraError(),
                        )
                      : const _ScanPlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _manual,
                icon: const Icon(Icons.keyboard),
                label: const Text('QR 값 직접 입력'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.crop_free, size: 56, color: muted),
      SizedBox(height: 8),
      Text(
        'QR 스캔 영역',
        style: TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.no_photography, color: muted, size: 48),
        SizedBox(height: 12),
        Text('카메라 권한이 필요합니다', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text(
          '설정에서 카메라 접근을 허용하거나\n아래 "QR 값 직접 입력"을 이용해 주세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ],
    ),
  );
}

// ===================== 알림 =====================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _unreadOnly = false;

  String _group(DateTime t) {
    final days = AppStore.kstDate(store.now()).difference(AppStore.kstDate(t)).inDays;
    return days == 0 ? '오늘' : (days == 1 ? '어제' : '이전');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: festBar(context),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.myNotifications().where((n) => !_unreadOnly || n.readAt == null).toList();
          String? last;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilterChips(
                values: const [false, true],
                selected: _unreadOnly,
                label: (v) => v ? '읽지 않음' : '전체',
                onSelect: (v) => setState(() => _unreadOnly = v),
              ),
              if (list.isEmpty) const EmptyView('받은 알림이 없습니다'),
              for (final n in list) ...[
                if (_group(n.createdAt) != last)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Text(last = _group(n.createdAt), style: const TextStyle(color: muted)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: n.readAt == null ? brandSoft : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                      title: Text(
                        n.content,
                        style: TextStyle(fontWeight: n.readAt == null ? FontWeight.w700 : FontWeight.w400),
                      ),
                      subtitle: Text('${n.type.label} · ${ago(n.createdAt)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        store.markRead(n);
                        push(context, EventDetailScreen(eventId: n.eventId));
                      },
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
