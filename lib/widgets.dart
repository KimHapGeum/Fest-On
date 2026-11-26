import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'store.dart';

// 아이콘 그림에서 뽑은 색
const brand = Color(0xFF2F5BD8);
const brandDark = Color(0xFF26408F);
const brandSoft = Color(0xFFE9F0FD);
const ink = Color(0xFF1C2333);
const muted = Color(0xFF6B7385);

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brand, primary: brand, surface: Colors.white);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F8FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD9DFEA))),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD9DFEA))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE6EAF2))),
    ),
  );
}

/// assets/icons의 그림 아이콘
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 26});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icons/$name.png', width: size, height: size, fit: BoxFit.contain);
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = '확인'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime t) => '${t.year}.${two(t.month)}.${two(t.day)}';
String fmtTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String fmtDateTime(DateTime t) => '${fmtDate(t)} ${fmtTime(t)}';
String fmtRange(DateTime a, DateTime b) => '${fmtDate(a)} ~ ${fmtDate(b)}';

String ago(DateTime t) {
  final d = store.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  return '${d.inDays}일 전';
}

/// image_url 값을 그린다. local:은 고른 사진, http는 인터넷 그림, 사진이 없으면 회색 칸에 글자만 쓴다.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.label = '사진', this.fit = BoxFit.cover});
  final String url;
  final String label;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageSrc(this.url); // 서버에 올린 사진은 '/images/…'로 저장된다
    final bytes = store.localImages[url];
    if (bytes != null) return Image.memory(bytes, fit: fit);
    if (url.startsWith('http')) {
      // 축제 이미지 서버(visitkorea·mcst 등)는 CORS 헤더가 없어, 웹에서는 막히면 <img> 태그로 대신 그린다
      return Image.network(url,
          fit: fit, webHtmlElementStrategy: WebHtmlElementStrategy.fallback, errorBuilder: (_, _, _) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => ColoredBox(
        color: const Color(0xFFDDE1E8),
        child: Center(child: Text(label, style: const TextStyle(color: muted, fontWeight: FontWeight.w600))),
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      EventStatus.ongoing => (const Color(0xFFE3F6EC), const Color(0xFF1E8E55)),
      EventStatus.ready => (brandSoft, brand),
      EventStatus.ended => (const Color(0xFFEEF0F4), muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Color levelColor(Level l) => switch (l) {
      Level.free => const Color(0xFF1E8E55),
      Level.normal => const Color(0xFFE08A00),
      Level.busy => const Color(0xFFE0403A),
      Level.unknown => muted,
    };

class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key});
  final Level level;

  @override
  Widget build(BuildContext context) {
    final c = levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(level.label, style: TextStyle(color: c, fontWeight: FontWeight.w800)),
    );
  }
}

/// 목록에 쓰는 행사 카드. 왼쪽 그림, 오른쪽 이름·설명·상태.
class EventTile extends StatelessWidget {
  const EventTile(this.event, {super.key, this.onTap, this.trailing, this.subtitle});
  final Event event;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 92, height: 92, child: NetImage(e.imageUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      StatusBadge(store.statusOf(e)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${e.region} · ${store.category(e.categoryId)?.name ?? ''}',
                            style: const TextStyle(color: muted, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(e.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(e.description,
                        style: const TextStyle(color: muted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(subtitle ?? fmtRange(e.startAt, e.endAt), style: const TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const Opacity(opacity: 0.5, child: AppIcon('search', size: 56)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: muted)),
        ]),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Padding(padding: EdgeInsets.all(10), child: AppIcon('search', size: 22)),
        ),
      );
}

/// 상단 앱 이름(로고). 누르면 첫 탭(홈)으로 돌아간다.
class LogoTitle extends StatelessWidget {
  const LogoTitle({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '라두나 홈으로',
        child: GestureDetector(
          onTap: () => HomeJump.of(context)?.call(),
          child: Image.asset('assets/icons/logo.png', height: 40),
        ),
      );
}

/// 탭 화면 어디서든 홈 탭으로 돌아가게 하는 신호.
class HomeJump extends InheritedWidget {
  const HomeJump({super.key, required this.jump, required super.child});
  final VoidCallback jump;

  static VoidCallback? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HomeJump>()?.jump;

  @override
  bool updateShouldNotify(HomeJump oldWidget) => false;
}

/// 상태 필터 칩 한 줄 (전체/예정된/진행중/종료된)
class FilterChips<T> extends StatelessWidget {
  const FilterChips({super.key, required this.values, required this.selected, required this.label, required this.onSelect});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final v in values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label(v)),
                  selected: v == selected,
                  onSelected: (_) => onSelect(v),
                ),
              ),
          ],
        ),
      );
}

/// 상태 필터 값: null은 전체
enum StatusFilter {
  all('전체'),
  upcoming('예정된 행사'),
  ongoing('진행중'),
  ended('종료된 행사');

  const StatusFilter(this.label);
  final String label;

  bool test(Event e) {
    final s = store.statusOf(e);
    return switch (this) {
      StatusFilter.all => true,
      StatusFilter.upcoming => s == EventStatus.ready && e.startAt.isAfter(store.now()),
      StatusFilter.ongoing => s == EventStatus.ongoing,
      StatusFilter.ended => s == EventStatus.ended,
    };
  }
}
