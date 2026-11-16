-- Fest-On 테이블 생성 SQL (오합지졸_테이블정의서 v0.5 기준, PostgreSQL 14 이상, UTF-8)
-- 앱은 아직 메모리 저장소(lib/store.dart)를 쓴다. 서버를 붙일 때 이 스키마로 DB를 만든다.

-- ============ 값 목록 ============
CREATE TYPE social_provider   AS ENUM ('NAVER', 'KAKAO', 'APPLE', 'GOOGLE');
CREATE TYPE event_status      AS ENUM ('READY', 'ONGOING', 'ENDED');
CREATE TYPE congestion_level  AS ENUM ('UNKNOWN', 'FREE', 'NORMAL', 'BUSY');
CREATE TYPE visit_source      AS ENUM ('QR', 'MANUAL', 'OTHER');
CREATE TYPE notification_type AS ENUM ('EVENT_UPDATE', 'PARKING', 'CROWD');

-- updated_at 자동 갱신 (PostgreSQL에는 ON UPDATE가 없다)
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============ 회원 ============
CREATE TABLE participant (
  participant_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  login_id          VARCHAR(50),
  password_hash     VARCHAR(255),
  name              VARCHAR(50)  NOT NULL,
  email             VARCHAR(100) NOT NULL,
  address           VARCHAR(255),
  profile_image_url VARCHAR(500),
  bio               VARCHAR(200),
  terms_agreed_at   TIMESTAMPTZ,
  notify_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
  notify_sound      VARCHAR(50),
  notify_preview    BOOLEAN NOT NULL DEFAULT TRUE,
  notify_parking    BOOLEAN NOT NULL DEFAULT TRUE,
  notify_crowd      BOOLEAN NOT NULL DEFAULT TRUE,
  push_token        VARCHAR(255),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at        TIMESTAMPTZ
);
-- 탈퇴하지 않은 회원끼리만 중복 불가 (탈퇴 후 재가입 허용)
CREATE UNIQUE INDEX uq_participant_login_id ON participant (login_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_participant_email    ON participant (email)    WHERE deleted_at IS NULL;
CREATE TRIGGER trg_participant_updated BEFORE UPDATE ON participant FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE organizer (
  organizer_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  login_id          VARCHAR(50),
  password_hash     VARCHAR(255),
  name              VARCHAR(50)  NOT NULL,
  email             VARCHAR(100) NOT NULL,
  profile_image_url VARCHAR(500),
  terms_agreed_at   TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at        TIMESTAMPTZ
);
CREATE UNIQUE INDEX uq_organizer_login_id ON organizer (login_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_organizer_email    ON organizer (email)    WHERE deleted_at IS NULL;
CREATE TRIGGER trg_organizer_updated BEFORE UPDATE ON organizer FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE participant_social (
  social_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  participant_id   BIGINT NOT NULL REFERENCES participant (participant_id) ON DELETE CASCADE,
  provider         social_provider NOT NULL,
  provider_user_id VARCHAR(255)    NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_participant_social UNIQUE (provider, provider_user_id)
);

CREATE TABLE organizer_social (
  social_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organizer_id     BIGINT NOT NULL REFERENCES organizer (organizer_id) ON DELETE CASCADE,
  provider         social_provider NOT NULL,
  provider_user_id VARCHAR(255)    NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_organizer_social UNIQUE (provider, provider_user_id)
);

-- ============ 행사 ============
CREATE TABLE category (
  category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE event (
  event_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organizer_id     BIGINT NOT NULL REFERENCES organizer (organizer_id) ON DELETE RESTRICT,
  event_name       VARCHAR(100) NOT NULL,
  image_url        VARCHAR(500) NOT NULL,
  description      TEXT NOT NULL,
  visit_info       TEXT,
  program          TEXT,
  status           event_status NOT NULL DEFAULT 'READY',
  start_at         TIMESTAMPTZ  NOT NULL,
  end_at           TIMESTAMPTZ  NOT NULL,
  region           VARCHAR(50)  NOT NULL,
  category_id      BIGINT NOT NULL REFERENCES category (category_id) ON DELETE RESTRICT,
  address          VARCHAR(255) NOT NULL,
  latitude         NUMERIC(10,7) NOT NULL,
  longitude        NUMERIC(10,7) NOT NULL,
  capacity         INTEGER NOT NULL CHECK (capacity >= 1),
  parking_location VARCHAR(255),
  parking_total    INTEGER CHECK (parking_total >= 0),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at       TIMESTAMPTZ,
  CONSTRAINT ck_event_period CHECK (end_at > start_at)
);
-- 매년 열리는 같은 이름의 축제를 허용: (이름, 시작 일시) 묶음으로, 삭제된 행사는 제외
CREATE UNIQUE INDEX uq_event_name_start ON event (event_name, start_at) WHERE deleted_at IS NULL;
CREATE INDEX ix_event_filter ON event (region, category_id, start_at) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_event_updated BEFORE UPDATE ON event FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE event_status_snapshot (
  event_id           BIGINT PRIMARY KEY REFERENCES event (event_id) ON DELETE CASCADE,
  parking_current    INTEGER CHECK (parking_current >= 0),
  parking_level      congestion_level NOT NULL DEFAULT 'UNKNOWN',
  parking_updated_at TIMESTAMPTZ,
  crowd_level        congestion_level NOT NULL DEFAULT 'UNKNOWN',
  crowd_updated_at   TIMESTAMPTZ
);

CREATE TABLE event_guide (
  guide_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id      BIGINT NOT NULL REFERENCES event (event_id) ON DELETE CASCADE,
  guide_name    VARCHAR(100) NOT NULL,
  map_image_url VARCHAR(500) NOT NULL,
  program       TEXT NOT NULL,
  qr_token      VARCHAR(255) NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_event_guide_event ON event_guide (event_id);
CREATE TRIGGER trg_event_guide_updated BEFORE UPDATE ON event_guide FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE guide_schedule (
  schedule_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guide_id    BIGINT NOT NULL REFERENCES event_guide (guide_id) ON DELETE CASCADE,
  title       VARCHAR(100) NOT NULL,
  start_at    TIMESTAMPTZ NOT NULL,
  end_at      TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_schedule_period CHECK (end_at > start_at)
);
CREATE INDEX ix_guide_schedule_guide ON guide_schedule (guide_id, start_at);
CREATE TRIGGER trg_guide_schedule_updated BEFORE UPDATE ON guide_schedule FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============ 참여자 활동 ============
CREATE TABLE favorite_event (
  participant_id BIGINT NOT NULL REFERENCES participant (participant_id) ON DELETE CASCADE,
  event_id       BIGINT NOT NULL REFERENCES event (event_id) ON DELETE CASCADE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (participant_id, event_id)
);
CREATE INDEX ix_favorite_event_event ON favorite_event (event_id);

CREATE TABLE visit_record (
  participant_id BIGINT NOT NULL REFERENCES participant (participant_id) ON DELETE RESTRICT,
  event_id       BIGINT NOT NULL REFERENCES event (event_id) ON DELETE RESTRICT,
  visited_at     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  visit_date     DATE         NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Seoul')::date,
  source         visit_source NOT NULL DEFAULT 'QR',
  PRIMARY KEY (participant_id, event_id, visit_date) -- 같은 날 같은 행사는 한 번만
);
CREATE INDEX ix_visit_record_crowd ON visit_record (event_id, visited_at); -- 최근 N분 방문 수 집계용

CREATE TABLE notification (
  notification_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  participant_id  BIGINT NOT NULL REFERENCES participant (participant_id) ON DELETE RESTRICT,
  event_id        BIGINT NOT NULL REFERENCES event (event_id) ON DELETE RESTRICT,
  type            notification_type NOT NULL,
  content         VARCHAR(255) NOT NULL,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_notification_inbox ON notification (participant_id, created_at DESC);
CREATE INDEX ix_notification_dedupe ON notification (participant_id, event_id, type, created_at);

-- 행사 종류 기본값
INSERT INTO category (name) VALUES ('지역 문화'), ('먹거리'), ('전통문화'), ('음악·공연'), ('불꽃·야경');
