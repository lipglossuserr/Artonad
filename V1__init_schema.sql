-- V1__init_schema.sql  (owner: Dev1)
-- Sprint 1 domain tables. 'location' columns are GENERATED from lat/lng.
-- PostGIS point order is (lng, lat) -- the generated column handles it.

CREATE EXTENSION IF NOT EXISTS postgis;

-- ---------- risk_zones ----------
CREATE TABLE risk_zones (
                            id          BIGSERIAL PRIMARY KEY,
                            name        VARCHAR(100) NOT NULL,
                            risk_level  VARCHAR(10)  NOT NULL,
                            boundary    geometry(Polygon, 4326) NOT NULL,
                            CONSTRAINT chk_risk_zones_level CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
                            CONSTRAINT chk_risk_zones_valid CHECK (ST_IsValid(boundary))
);
CREATE INDEX idx_risk_zones_boundary ON risk_zones USING GIST (boundary);

-- ---------- resorts ----------
CREATE TABLE resorts (
                         id              BIGSERIAL PRIMARY KEY,
                         name            VARCHAR(100) NOT NULL,
                         lat             DOUBLE PRECISION NOT NULL,
                         lng             DOUBLE PRECISION NOT NULL,
                         fire_equipment  TEXT,
                         location        geography(Point, 4326)
        GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
                         CONSTRAINT chk_resorts_lat CHECK (lat BETWEEN -90 AND 90),
                         CONSTRAINT chk_resorts_lng CHECK (lng BETWEEN -180 AND 180)
);
CREATE INDEX idx_resorts_location ON resorts USING GIST (location);

-- ---------- responders ----------
CREATE TABLE responders (
                            id         BIGSERIAL PRIMARY KEY,
                            name       VARCHAR(100) NOT NULL,
                            role       VARCHAR(20)  NOT NULL,
                            available  BOOLEAN      NOT NULL DEFAULT TRUE,
                            lat        DOUBLE PRECISION NOT NULL,
                            lng        DOUBLE PRECISION NOT NULL,
                            location   geography(Point, 4326)
        GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
                            CONSTRAINT chk_responders_role CHECK (role IN ('LIFEGUARD', 'FIREFIGHTER')),
                            CONSTRAINT chk_responders_lat  CHECK (lat BETWEEN -90 AND 90),
                            CONSTRAINT chk_responders_lng  CHECK (lng BETWEEN -180 AND 180)
);
CREATE INDEX idx_responders_location ON responders USING GIST (location);
CREATE INDEX idx_responders_role_available ON responders (role, available);

-- ---------- incidents ----------
CREATE TABLE incidents (
                           id                         BIGSERIAL PRIMARY KEY,
                           type                       VARCHAR(20) NOT NULL,
                           severity                   VARCHAR(10) NOT NULL,
                           people_count               INTEGER     NOT NULL,
                           note                       TEXT,
                           lat                        DOUBLE PRECISION NOT NULL,
                           lng                        DOUBLE PRECISION NOT NULL,
                           location                   geography(Point, 4326)
        GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
                           status                     VARCHAR(20) NOT NULL DEFAULT 'REPORTED',
                           zone_id                    BIGINT REFERENCES risk_zones (id),
                           nearest_resort_id          BIGINT REFERENCES resorts (id),
                           nearest_resort_distance_m  INTEGER,
                           reporter_id                BIGINT,          -- FK to users added after Dev2's users table exists
                           created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
                           CONSTRAINT chk_incidents_type     CHECK (type IN ('FIRE', 'DROWNING')),
                           CONSTRAINT chk_incidents_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
                           CONSTRAINT chk_incidents_status   CHECK (status IN ('REPORTED', 'ASSIGNED', 'ACCEPTED', 'DECLINED', 'RESOLVED')),
                           CONSTRAINT chk_incidents_people   CHECK (people_count >= 1),
                           CONSTRAINT chk_incidents_lat      CHECK (lat BETWEEN -90 AND 90),
                           CONSTRAINT chk_incidents_lng      CHECK (lng BETWEEN -180 AND 180)
);
CREATE INDEX idx_incidents_location   ON incidents USING GIST (location);
CREATE INDEX idx_incidents_created_at ON incidents (created_at DESC);
CREATE INDEX idx_incidents_reporter   ON incidents (reporter_id);