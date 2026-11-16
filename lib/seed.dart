import 'models.dart';
import 'store.dart';

/// 시연용 샘플 데이터. 날짜는 오늘을 기준으로 잡아 진행중·예정·종료가 늘 섞여 보이게 한다.
/// 로그인: 참여자 user1 / pass1234, 개최자 org1 / pass1234
void seedStore(AppStore s) {
  final now = s.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour) => today.add(Duration(days: dayOffset, hours: hour));

  s.categories.addAll(const [
    Category(1, '지역 문화'),
    Category(2, '먹거리'),
    Category(3, '전통문화'),
    Category(4, '음악·공연'),
    Category(5, '불꽃·야경'),
  ]);

  final user = Member(
    id: 1,
    role: Role.participant,
    loginId: 'user1',
    passwordHash: AppStore.hash('pass1234'),
    name: '홍길동',
    email: 'testuser@example.com',
    bio: '주말마다 동네 축제를 찾아다녀요',
    termsAgreedAt: now,
    notifySound: '기본',
  );
  s.participants.add(user);
  final org1 = Member(
      id: 2, role: Role.organizer, loginId: 'org1', passwordHash: AppStore.hash('pass1234'),
      name: '두드림 축제 운영위원회', email: 'org@example.com', termsAgreedAt: now);
  final org2 = Member(
      id: 3, role: Role.organizer, loginId: 'org2', passwordHash: AppStore.hash('pass1234'),
      name: '바다마을 협동조합', email: 'org2@example.com', termsAgreedAt: now);
  s.organizers.addAll([org1, org2]);

  // 관심순·혼잡도가 보이도록 손님 회원을 둔다
  for (var i = 0; i < 40; i++) {
    s.participants.add(Member(id: 10 + i, role: Role.participant, name: '손님$i', email: 'guest$i@example.com'));
  }

  var id = 1000;
  Event ev(String name, int org, int cat, String region, String addr, double lat, double lng, DateTime start,
          DateTime end, EventStatus status,
          {required String desc, int capacity = 40, int? parking, String? parkingAt, int createdDaysAgo = 1}) =>
      Event(
        id: ++id,
        organizerId: org,
        name: name,
        imageUrl: 'placeholder:$id',
        description: desc,
        visitInfo: '운영 시간 10:00 ~ 21:00\n대중교통 이용을 권장합니다.\n행사장 안 흡연 금지, 반려동물은 목줄 필수.',
        program: '개막 공연, 체험 부스, 야간 공연',
        status: status,
        startAt: start,
        endAt: end,
        region: region,
        categoryId: cat,
        address: addr,
        latitude: lat,
        longitude: lng,
        capacity: capacity,
        parkingTotal: parking,
        parkingLocation: parkingAt,
        createdAt: now.subtract(Duration(days: createdDaysAgo)),
      );

  final dodream = ev('2026 두드림 문화 축제', 2, 1, '서울', '서울 중구 세종대로 110 서울광장', 37.5663, 126.9779, at(-1, 10),
      at(2, 21), EventStatus.ongoing,
      desc: '시민이 함께 만드는 도심 문화 축제. 거리 공연, 전통 체험, 야간 콘서트가 열려요.',
      parking: 200, parkingAt: '서울광장 지하 공영주차장', capacity: 40, createdDaysAgo: 3);
  final lantern = ev('청계천 등불 축제', 2, 5, '서울', '서울 중구 청계천로 1', 37.5690, 126.9787, at(-3, 17), at(4, 23),
      EventStatus.ongoing,
      desc: '청계천을 따라 수백 개의 등불이 밤을 밝혀요. 소원 등 만들기 체험도 있어요.',
      parking: 80, parkingAt: '청계광장 인근 공영주차장', capacity: 30, createdDaysAgo: 6);
  final fireworks = ev('한강 불꽃 야경제', 2, 5, '서울', '서울 영등포구 여의동로 330 여의도한강공원', 37.5284, 126.9327, at(5, 18),
      at(5, 22), EventStatus.ready,
      desc: '한강 위로 펼쳐지는 불꽃 쇼와 음악. 돗자리를 챙겨 오세요.', parking: 500, parkingAt: '여의도한강공원 1~5주차장', createdDaysAgo: 2);
  final namsan = ev('남산 가을 음악회', 2, 4, '서울', '서울 중구 삼일대로 231 남산공원', 37.5512, 126.9882, at(2, 15), at(3, 20),
      EventStatus.ready, desc: '단풍 아래에서 즐기는 어쿠스틱 공연.', createdDaysAgo: 0);
  final suwon = ev('수원 화성 전통 체험제', 2, 3, '경기', '경기 수원시 팔달구 정조로 825', 37.2871, 127.0119, at(-2, 10),
      at(1, 18), EventStatus.ongoing,
      desc: '성곽길을 걸으며 활쏘기, 전통 놀이, 한복 체험을 해요.', parking: 150, parkingAt: '화성행궁 공영주차장', createdDaysAgo: 8);
  final market = ev('인천 개항장 야시장', 3, 2, '인천', '인천 중구 신포로 27', 37.4739, 126.6216, at(-1, 17), at(6, 23),
      EventStatus.ongoing, desc: '개항장 거리의 먹거리 야시장. 지역 상인 50여 곳이 참여해요.', parking: 60, parkingAt: '신포시장 공영주차장', createdDaysAgo: 4);
  final busan = ev('부산 바다 먹거리 축제', 3, 2, '부산', '부산 해운대구 해운대해변로 264', 35.1587, 129.1604, at(-25, 10),
      at(-20, 21), EventStatus.ended, desc: '해운대 바닷가에서 즐기는 해산물 먹거리 장터.', createdDaysAgo: 40);
  final gangneung = ev('강릉 커피 음악회', 2, 4, '강원', '강원 강릉시 창해로 17 안목해변', 37.7956, 128.9188, at(10, 13),
      at(12, 20), EventStatus.ready, desc: '바다와 커피, 버스킹 공연이 함께하는 음악회.', createdDaysAgo: 5);
  final jeonju = ev('전주 한옥 전통 놀이마당', 2, 3, '전라', '전북 전주시 완산구 기린대로 99', 35.8151, 127.1530, at(-40, 10),
      at(-37, 18), EventStatus.ended, desc: '한옥마을 골목에서 펼쳐지는 전통 놀이와 공연.', createdDaysAgo: 60);
  s.events.addAll([dodream, lantern, fireworks, namsan, suwon, market, busan, gangneung, jeonju]);

  // 관심 행사
  for (final e in [dodream, fireworks, gangneung]) {
    s.favorites.add(FavoriteEvent(user.id, e.id));
  }
  final popularity = {dodream: 18, lantern: 12, fireworks: 25, suwon: 7, market: 9, namsan: 3, gangneung: 5, busan: 4};
  popularity.forEach((e, n) {
    for (var i = 0; i < n; i++) {
      s.favorites.add(FavoriteEvent(10 + i, e.id));
    }
  });

  // 최근 1시간 방문으로 혼잡도를 만든다: 두드림 30/40=혼잡, 청계천 18/30=보통, 수원 8/40=여유
  void visitsNow(Event e, int n) {
    for (var i = 0; i < n; i++) {
      final t = now.subtract(Duration(minutes: 2 + i));
      s.visits.add(VisitRecord(10 + i, e.id, t, AppStore.kstDate(t), VisitSource.qr));
    }
    s.recalcCrowd(e.id);
  }

  visitsNow(dodream, 30);
  visitsNow(lantern, 18);
  visitsNow(suwon, 8);

  // 내 방문 기록
  for (final (e, daysAgo) in [(busan, 22), (jeonju, 38), (suwon, 1)]) {
    final t = now.subtract(Duration(days: daysAgo, hours: 2));
    s.visits.add(VisitRecord(user.id, e.id, t, AppStore.kstDate(t), VisitSource.qr));
  }

  // 주차 현황 (개최자 입력값)
  void parking(Event e, int current) {
    final snap = s.snapshot(e.id)
      ..parkingCurrent = current
      ..parkingUpdatedAt = now.subtract(const Duration(minutes: 15));
    snap.parkingLevel = AppStore.levelFromRatio(current / e.parkingTotal!);
  }

  parking(dodream, 172);
  parking(lantern, 30);
  parking(suwon, 95);
  parking(market, 41);

  // 가이드와 스케줄
  EventGuide guide(Event e, String name, String program, List<(String, int, int)> items) {
    final g = EventGuide(
        id: s.nextId(), eventId: e.id, guideName: name, mapImageUrl: 'placeholder:map', program: program,
        qrToken: AppStore.newQrToken());
    s.guides.add(g);
    for (final (title, from, to) in items) {
      s.schedules.add(GuideSchedule(
          id: s.nextId(), guideId: g.id, title: title, startAt: at(0, from), endAt: at(0, to)));
    }
    return g;
  }

  guide(dodream, 'A구역 메인무대', '개막식, 거리 공연, 야간 콘서트',
      [('개막식', 10, 11), ('거리 공연', 13, 16), ('야간 콘서트', 19, 21)]);
  guide(dodream, '먹거리존', '지역 맛집 부스 20곳, 푸드트럭', [('푸드트럭 운영', 11, 20)]);
  guide(lantern, '등불 산책로', '소원 등 만들기, 등불 퍼레이드', [('소원 등 만들기', 17, 19), ('등불 퍼레이드', 20, 21)]);
  guide(suwon, '화성행궁 체험장', '활쏘기, 한복 체험, 전통 놀이', [('활쏘기', 10, 12), ('한복 체험', 13, 17)]);
  guide(fireworks, '여의도 관람존', '불꽃 쇼, 음악 공연', [('사전 공연', 18, 19), ('불꽃 쇼', 19, 21)]);

  // 알림 (두드림 혼잡 알림은 위 recalcCrowd가 이미 보냈다)
  s.notifications.add(AppNotification(s.nextId(), user.id, fireworks.id, NotiType.eventUpdate, '관심 행사 "한강 불꽃 야경제" 정보가 변경되었어요',
        now.subtract(const Duration(hours: 5)))..readAt = now.subtract(const Duration(hours: 4)));
}
