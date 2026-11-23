"""한국관광공사 TourAPI(국문 관광정보 KorService2)의 행사정보를 받아 tool/tourapi_festivals.json에 저장한다.

    TOUR_API_KEY=<일반 인증키(Decoding)> python -I tool/fetch_tourapi.py

인증키는 환경 변수로만 받는다. 코드나 저장소에 넣지 않는다.
받은 파일은 import_festivals.py에 다른 CSV와 함께 넘기면 된다.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'tourapi_festivals.json'
URL = 'https://apis.data.go.kr/B551011/KorService2/searchFestival2'


def page(key: str, no: int, rows: int = 500) -> dict:
    q = urllib.parse.urlencode({'serviceKey': key, 'MobileOS': 'ETC', 'MobileApp': 'Raduna', '_type': 'json',
                                'numOfRows': rows, 'pageNo': no, 'eventStartDate': '20260101', 'arrange': 'A'})
    with urllib.request.urlopen(f'{URL}?{q}', timeout=60) as r:
        data = json.load(r)
    head = data['response']['header']
    if head['resultCode'] != '0000':
        raise RuntimeError(f"TourAPI 오류 {head['resultCode']}: {head['resultMsg']}")
    return data['response']['body']


DETAIL_URL = 'https://apis.data.go.kr/B551011/KorService2/detailCommon2'
DETAIL_FIELDS = ('overview', 'homepage', 'telname')


def detail(key: str, content_id: str) -> dict:
    q = urllib.parse.urlencode({'serviceKey': key, 'MobileOS': 'ETC', 'MobileApp': 'Raduna', '_type': 'json',
                                'contentId': content_id})
    with urllib.request.urlopen(f'{DETAIL_URL}?{q}', timeout=60) as r:
        data = json.load(r)
    head = data['response']['header']
    if head['resultCode'] != '0000':
        raise RuntimeError(f"TourAPI 오류 {head['resultCode']}: {head['resultMsg']}")
    got = data['response']['body']['items']
    return got['item'][0] if got else {}


def save(items):
    """OneDrive가 동기화 중인 파일을 덮어쓰면 Errno 22가 나서, 임시 파일에 쓰고 바꿔치기하며 몇 번 다시 해 본다."""
    tmp = OUT.with_suffix('.tmp')
    tmp.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding='utf-8')
    for wait in (0, 1, 3, 10):
        time.sleep(wait)
        try:
            os.replace(tmp, OUT)
            return
        except OSError:
            continue
    raise OSError(f'{OUT.name}을(를) 쓰지 못했습니다. 받은 내용은 {tmp.name}에 있습니다')


def main():
    key = os.environ.get('TOUR_API_KEY')
    if not key:
        sys.exit('TOUR_API_KEY 환경 변수에 일반 인증키를 넣어 주세요')
    old = {x['contentid']: x for x in json.loads(OUT.read_text(encoding='utf-8'))} if OUT.exists() else {}
    items, no = [], 1
    while True:
        body = page(key, no)
        got = body['items']['item'] if body['items'] else []
        items += got
        if not got or len(items) >= body['totalCount']:
            break
        no += 1
    for x in items:  # 전에 받은 상세 정보는 다시 묻지 않게 옮겨 둔다
        for f in DETAIL_FIELDS:
            if f in old.get(x['contentid'], {}):
                x[f] = old[x['contentid']][f]
    save(items)
    print(f"{len(items)}건 (전체 {body['totalCount']}) → {OUT.name}, 이미지 있음 {sum(1 for x in items if x.get('firstimage'))}건")

    # 상세(소개 글). 하루 호출 한도에 걸리면 받은 데까지 저장하고 멈춘다. 다시 돌리면 남은 것만 받는다
    todo = [x for x in items if 'overview' not in x]
    try:
        for i, x in enumerate(todo, 1):
            d = detail(key, x['contentid'])
            for f in DETAIL_FIELDS:
                x[f] = d.get(f, '')
            if i % 50 == 0:
                save(items)
                print(f'상세 {i}/{len(todo)}', flush=True)
    finally:
        save(items)
        print(f"상세 받음: {sum(1 for x in items if 'overview' in x)}/{len(items)}")


if __name__ == '__main__':
    main()
