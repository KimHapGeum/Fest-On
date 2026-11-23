import 'package:fest_on/models.dart';
import 'package:fest_on/screens/organizer.dart';
import 'package:fest_on/screens/participant.dart';
import 'package:fest_on/store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('홈 지역 메뉴: 전체 지역과 다른 지역 선택', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    store.login(Role.participant, 'user1', 'pass1234');
    await t.pumpWidget(const MaterialApp(home: HomeScreen()));
    await t.pump();
    expect(find.text('서울'), findsWidgets);
    await t.tap(find.byTooltip('지역'));
    await t.pumpAndSettle();
    await t.tap(find.text('전체 지역').last);
    await t.pumpAndSettle();
    expect(find.text('지역'), findsOneWidget); // 칩 글자가 '지역'으로 바뀜 = 전체
    await t.tap(find.byTooltip('지역'));
    await t.pumpAndSettle();
    await t.tap(find.text('경기').last);
    await t.pumpAndSettle();
    expect(find.text('수원 화성 전통 체험제'), findsWidgets);
    expect(find.text('남산 가을 음악회'), findsNothing);
  });

  testWidgets('행사 등록: 빈 필수 칸으로 커서 이동', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    store.login(Role.organizer, 'org1', 'pass1234');
    await t.pumpWidget(const MaterialApp(home: EventFormScreen()));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, '축제 제목 *'), '제목');
    await t.tap(find.text('작성 완료'));
    await t.pump();
    final desc = t.widget<TextField>(find.widgetWithText(TextField, '축제 설명 *'));
    expect(desc.focusNode!.hasFocus, isTrue);
    expect(find.text('필수 항목(축제 제목 등)을 입력해주세요'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });
}
