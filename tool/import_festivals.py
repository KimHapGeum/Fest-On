"""실제 축제 CSV를 lib/real_events.dart로 바꾼다. Raduna_Data.csv 형식과 공공데이터포털 전국문화축제표준데이터를 받는다.

    python -I tool/import_festivals.py Raduna_Data.csv 전국문화축제표준데이터.csv

- 위도·경도가 비어 있으면 주소로 OpenStreetMap Nominatim에 물어 tool/geocode_cache.json에 남긴다(초당 1건).
- 지역은 앱의 9개 묶음(AppStore.regions)으로, 종류는 이름·분류의 낱말로 정한다.
- 같은 source_key(없으면 이름|시작일)는 한 번만 넣는다.
"""
import csv
import html
import json
import re
import sys
import time
import urllib.parse
from datetime import date
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'tool' / 'geocode_cache.json'
OUT = ROOT / 'lib' / 'real_events.dart'

# 주소 앞부분 → 앱 지역 (AppStore.regions와 같은 값)
REGION_PREFIX = [
    ('서울', '서울'), ('경기', '경기'), ('인천', '인천'), ('강원', '강원'), ('부산', '부산'), ('제주', '제주'),
    ('대전', '충청'), ('세종', '충청'), ('충청', '충청'), ('충북', '충청'), ('충남', '충청'),
    ('광주', '전라'), ('전라', '전라'), ('전북', '전라'), ('전남', '전라'),
    ('대구', '경상'), ('울산', '경상'), ('경상', '경상'), ('경북', '경상'), ('경남', '경상'),
]

# 앞에서부터 먼저 맞는 종류. 번호는 seed.dart의 Category와 같다.
CATEGORY_RULES = [
    (4, r'공연|콘서트|음악|뮤지컬|연극|발레|교향|오페라|클래식|노래|음악극|무용|재즈|록페|락페|뮤직|가요제|국악|버스킹|댄스'),  # '대전시립'의 '전시'보다 먼저
    (6, r'박람회|페어|전시|도서전|데이터위크|산업대전|명장대전|마켓|창업|엑스포|비엔날레|영화제'),
    (5, r'빛|불꽃|트리|야경|눈꽃|초롱|일루미|겨울밤|등축제|유등|반딧불'),
    # 한 글자 낱말(김·배·감·밤·쌀)은 '김해', '배드민턴'처럼 다른 낱말에 섞여 들어가 넣지 않는다
    (2, r'먹거리|떡볶이|곶감|방어|송어|산천어|시금치|장단콩|와인|주류|김장|담그랑께|맛|딸기|사과|한우|김치|전어|라면|치맥|'
        r'고사리|홍삼|인삼|녹차|다향|숯불|대게|꽃게|대하|새우|멸치|미역|과메기|장어|낙지|주꾸미|오징어|굴축제|흑돼지|'
        r'토마토|고구마|감자|옥수수|마늘|양파|고추|복숭아|참외|수박|포도|매실|한과|젓갈|버섯|막걸리|맥주|커피|빵|'
        r'블루베리|자두|참깨|도토리|산나물|곰취|두릅|송이|한라봉|감귤|밀면|국밥|떡|쌀축제|햅쌀|치즈|호두|대추|오미자|'
        r'꼬막|전복|광어|가자미|해산물|수산물|한돈|음식|푸드|미식|별미|특산'),
    (3, r'전통|한옥|민속|국가유산|문화재|문화제|대첩|아리랑|풍물|탈춤|단오|향교|서원|읍성|성곽|대가야|백제|신라|가야|'
        r'선비|의병|충무공|세종|한글|도자기|공예|차문화|농악|줄다리기|씨름|천도재|제례|당제'),
]


def region_of(address: str) -> str:
    a = address.strip()
    for prefix, region in REGION_PREFIX:
        if a.startswith(prefix):
            return region
    raise ValueError(f'지역을 알 수 없는 주소: {address}')


def category_of(*texts: str) -> int:
    """앞의 글(이름)에서 먼저 찾고, 없을 때만 뒤의 글(분류·소개)을 본다. 소개 글의 '공연' 같은 낱말에 끌리지 않게."""
    for text in texts:
        for cat, pattern in CATEGORY_RULES:
            if re.search(pattern, text):
                return cat
    return 1  # 지역 문화


def load_cache() -> dict:
    return json.loads(CACHE.read_text(encoding='utf-8')) if CACHE.exists() else {}


def nominatim(q: str):
    url = 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode(
        {'q': q, 'format': 'json', 'countrycodes': 'kr', 'limit': 1})
    req = urllib.request.Request(url, headers={'User-Agent': 'raduna-festival-import/0.1'})
    time.sleep(1.1)  # Nominatim 이용 조건: 초당 1건
    with urllib.request.urlopen(req, timeout=30) as r:
        hits = json.load(r)
    return (float(hits[0]['lat']), float(hits[0]['lon'])) if hits else None


def geocode(address: str, venue: str, cache: dict):
    """정확한 주소 → 괄호 뺀 주소 → 장소명+시군구 → 시군구 중심 순으로 찾는다. (좌표, 정밀도)를 돌려준다."""
    base = re.sub(r'\s*\(.*?\)', '', address).strip()
    base = re.sub(r'([가-힣]+[시군구])([가-힣0-9]+(?:로|길))', r'\1 \2', base)  # '서초구남부순환로317길'처럼 붙은 주소
    words = base.split()
    tries = [(base, 'address')]
    if venue:
        tries.append((' '.join(words[:2] + [venue]), 'venue'))
    tries.append((' '.join(words[:3]), 'district'))
    tries.append((' '.join(words[:2]), 'district'))
    tries.append((words[0], 'province'))
    for q, level in tries:
        if q not in cache:
            cache[q] = nominatim(q)
            CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1), encoding='utf-8')
        if cache[q]:
            return cache[q], level
    raise ValueError(f'좌표를 찾지 못한 주소: {address}')


def dart_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False).replace('$', r'\$')


def rows_from_raduna(path: str):
    with open(path, encoding='utf-8-sig', newline='') as f:
        for x in csv.DictReader(f):
            desc = x['description'].strip() or x['visit_info'].strip()
            visit = [x['visit_info'].strip()] if x['description'].strip() and x['visit_info'].strip() else []
            for label, key in (('장소', 'venue'), ('요금', 'fee'), ('문의', 'contact'), ('홈페이지', 'official_url')):
                if x[key].strip():
                    visit.append(f'{label}: {x[key].strip()}')
            yield {
                'key': x['source_key'].strip() or f"{x['event_name']}|{x['source_start_date']}",
                'name': x['event_name'].strip(),
                'image': x['image_url'].strip(),
                'desc': desc or x['event_name'].strip(),
                'visit': '\n'.join(visit),
                'program': x['program'].strip(),
                'start': x['start_at'].strip(),
                'end': x['end_at'].strip(),
                'address': x['address'].strip(),
                'venue': x['venue'].strip(),
                'lat': x['latitude'].strip(),
                'lng': x['longitude'].strip(),
                'kind': x['source_category'].strip(),
                'source': f"{x['attribution_text'].strip()} ({x['source_url'].strip()})",
            }


def rows_from_std(path: str):
    """공공데이터포털 전국문화축제표준데이터 CSV (cp949)."""
    with open(path, encoding='cp949', newline='') as f:
        for x in csv.DictReader(f):
            visit = [f'{label}: {x[key].strip()}' for label, key in
                     (('장소', '개최장소'), ('주최', '주최기관명'), ('주관', '주관기관명'), ('문의', '전화번호'),
                      ('홈페이지', '홈페이지주소')) if x[key].strip()]
            yield {
                'name': x['축제명'].strip(),
                'image': '',
                'desc': x['축제내용'].strip() or x['축제명'].strip(),
                'visit': '\n'.join(visit),
                'program': '',
                'start': x['축제시작일자'].strip() + 'T00:00:00+09:00',
                'end': x['축제종료일자'].strip() + 'T23:59:59+09:00',
                'address': (x['소재지도로명주소'] or x['소재지지번주소']).strip(),
                'venue': x['개최장소'].strip(),
                'lat': x['위도'].strip(),
                'lng': x['경도'].strip(),
                'kind': '',
                'source': f"공공데이터포털 전국문화축제표준데이터 ({x['제공기관명'].strip()}, 기준일 {x['데이터기준일자'].strip()})",
            }


# 법정동 시·도 코드 → 앱 지역 (강원·전북은 특별자치도 전환 전후 코드가 둘)
LDONG_REGION = {'11': '서울', '26': '부산', '27': '경상', '28': '인천', '29': '전라', '30': '충청', '31': '경상', '36': '충청',
                '41': '경기', '42': '강원', '51': '강원', '43': '충청', '44': '충청', '45': '전라', '52': '전라', '46': '전라',
                '47': '경상', '48': '경상', '50': '제주'}


def plain(s: str) -> str:
    """TourAPI 글의 <br>·<a> 같은 HTML을 걷어 낸다."""
    s = re.sub(r'<br\s*/?>', '\n', s or '', flags=re.I)
    s = html.unescape(re.sub(r'<[^>]+>', '', s))
    return re.sub(r'\n{3,}', '\n\n', s).strip()


def rows_from_tourapi(path: str):
    """fetch_tourapi.py가 저장한 TourAPI 행사정보 JSON. 이미지는 공공누리 유형(cpyrhtDivCd)을 출처에 남긴다."""
    licence = {'Type1': '공공누리 제1유형', 'Type3': '공공누리 제3유형(출처표시·변경금지)'}
    for x in json.loads(Path(path).read_text(encoding='utf-8')):
        d = lambda s: f'{s[:4]}-{s[4:6]}-{s[6:8]}'
        tel = ' '.join(p for p in (plain(x.get('telname', '')), x.get('tel', '').strip()) if p)
        homepage = re.search(r'https?://[^\s"<>]+', x.get('homepage', '') or '')
        visit = [f'{label}: {v}' for label, v in (('장소', x.get('addr2', '').strip()), ('문의', tel),
                                                   ('홈페이지', homepage[0] if homepage else '')) if v]
        yield {
            'name': x['title'].strip(),
            'image': x.get('firstimage', '').strip(),
            'desc': plain(x.get('overview', '')) or x['title'].strip(),
            'visit': '\n'.join(visit),
            'program': '',
            'start': d(x['eventstartdate']) + 'T00:00:00+09:00',
            'end': d(x['eventenddate']) + 'T23:59:59+09:00',
            'address': x['addr1'].strip(),
            'venue': x.get('addr2', '').strip(),
            'lat': x['mapy'],
            'lng': x['mapx'],
            'kind': '',
            'region': LDONG_REGION.get(x.get('lDongRegnCd', '')),  # 주소에 시·도가 빠진 행이 있다 ('포항시 북구 …')
            'source': f"한국관광공사 TourAPI (콘텐츠ID {x['contentid']}, 이미지 {licence.get(x['cpyrhtDivCd'], '유형 미표기')})",
        }


def read_rows(path: str):
    if path.endswith('.json'):
        return rows_from_tourapi(path)
    with open(path, 'rb') as f:
        head = f.read(200)
    return rows_from_raduna(path) if b'event_name' in head else rows_from_std(path)


def norm_name(r) -> str:
    """'2026 제24회 논산 양촌곶감축제'와 '논산양촌곶감축제'를 같은 이름으로 본다."""
    return re.sub(r'20\d\d|제\s*\d+\s*회|[\s\W_]', '', r['name'])


def start_day(r) -> int:
    return date.fromisoformat(r['start'][:10]).toordinal()


SAME_EVENT_DAYS = 14  # 출처마다 시작일이 며칠씩 다르다 (부산항축제 6/19·6/20). 해가 다르면 다른 회차로 본다


def in_korea(lat, lng) -> bool:
    try:
        return 33 <= float(lat) <= 39 and 124 <= float(lng) <= 132
    except ValueError:
        return False


SINCE = '2026-01-01'  # 이보다 먼저 끝난 행사(지난 해 개최 기록)는 넣지 않는다


def main(paths):
    cache = load_cache()
    seen, out, levels, skipped = {}, [], {}, {'old': 0, 'dup': 0, 'image_filled': 0, 'coords_fixed': 0}
    for p in paths:  # 앞의 파일이 우선. 뒤 파일의 같은 행사는 빈 이미지·대략적인 좌표만 채운다
        for r in read_rows(p):
            if r['end'][:10] < SINCE:
                skipped['old'] += 1
                continue
            same = [e for e in seen.get(norm_name(r), []) if abs(start_day(e[0]) - start_day(r)) <= SAME_EVENT_DAYS]
            if same:
                skipped['dup'] += 1
                old = same[0]
                if not old[0]['image'] and r['image']:
                    old[0]['image'] = r['image']
                    old[0]['source'] += f"; 이미지: {r['source']}"
                    skipped['image_filled'] += 1
                if old[0]['desc'] == old[0]['name'] and r['desc'] != r['name']:  # 소개가 이름뿐이었으면 채운다
                    old[0]['desc'] = r['desc']
                    skipped['desc_filled'] = skipped.get('desc_filled', 0) + 1
                if old[3] in ('district', 'province') and in_korea(r['lat'], r['lng']):
                    old[1], old[2], old[3] = float(r['lat']), float(r['lng']), 'source'
                    skipped['coords_fixed'] += 1
                continue
            if in_korea(r['lat'], r['lng']):
                (lat, lng), level = (float(r['lat']), float(r['lng'])), 'source'
            else:
                (lat, lng), level = geocode(r['address'], r['venue'], cache)
            assert 33 <= lat <= 39 and 124 <= lng <= 132, (r['name'], lat, lng)  # 한국 밖이면 잘못 찾은 것
            out.append([r, lat, lng, level])
            seen.setdefault(norm_name(r), []).append(out[-1])
    for _, _, _, level in out:
        levels[level] = levels.get(level, 0) + 1

    lines = [
        '// 자동 생성 파일: tool/import_festivals.py가 만든다. 직접 고치지 말고 CSV를 고쳐 다시 만든다.',
        '// 출처별 이용 조건(이미지·글 재사용)은 확인 전이라 공개 배포 전에 확인이 필요하다.',
        '',
        'typedef RealEvent = ({String name, String image, String desc, String visit, String program, String start,',
        '    String end, String region, int cat, String address, double lat, double lng, String source});',
        '',
        'const realEvents = <RealEvent>[',
    ]
    for r, lat, lng, _ in out:
        fields = dict(name=r['name'], image=r['image'], desc=r['desc'], visit=r['visit'], program=r['program'],
                      start=r['start'], end=r['end'], region=r.get('region') or region_of(r['address']))
        body = ', '.join(f'{k}: {dart_str(v)}' for k, v in fields.items())
        body += f", cat: {category_of(r['name'], r['kind'])}, address: {dart_str(r['address'])}"
        body += f", lat: {lat:.6f}, lng: {lng:.6f}, source: {dart_str(r['source'])}"
        lines.append(f'  ({body}),')
    lines.append('];')
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'{len(out)}건 → {OUT.relative_to(ROOT)}  좌표 정밀도: {levels}  건너뜀: {skipped}')


if __name__ == '__main__':
    main(sys.argv[1:])
