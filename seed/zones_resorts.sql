-- CoastGuard 360 / Artonad - Dev6 zone and resort seed data
-- Development/demo data only. Do NOT run against production.
-- Assumes V1__init_schema.sql has already created risk_zones and resorts.
--
-- GeoJSON coordinates are [longitude, latitude], and every polygon is closed.
-- Central Beach Medium is inserted before North Beach High-Risk intentionally:
-- their overlap is useful for testing deterministic risk-zone selection.
-- Gaps between polygons intentionally leave some beach area outside all zones.
--
-- WARNING: TRUNCATE ... CASCADE also deletes incidents referencing these rows.
-- Use only with a disposable development database.

BEGIN;

TRUNCATE TABLE risk_zones, resorts RESTART IDENTITY CASCADE;

INSERT INTO risk_zones (name, risk_level, boundary) VALUES
(
    'Central Beach Medium',
    'MEDIUM',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[92.007,21.428],[92.013,21.428],[92.013,21.433],[92.007,21.433],[92.007,21.428]]]}'
        ),
        4326
    )
),
(
    'North Beach High-Risk',
    'HIGH',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[92.003,21.426],[92.009,21.426],[92.009,21.431],[92.003,21.431],[92.003,21.426]]]}'
        ),
        4326
    )
),
(
    'South Beach Low',
    'LOW',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[92.003,21.415],[92.009,21.415],[92.009,21.420],[92.003,21.420],[92.003,21.415]]]}'
        ),
        4326
    )
),
(
    'East Beach High-Risk',
    'HIGH',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[92.015,21.426],[92.020,21.426],[92.020,21.431],[92.015,21.431],[92.015,21.426]]]}'
        ),
        4326
    )
);

-- id and location are intentionally omitted:
-- id is generated, and location is a generated geography column.
INSERT INTO resorts (name, lat, lng, fire_equipment) VALUES
(
    'Sea Pearl Resort',
    21.4310,
    92.0070,
    '2 extinguishers, 1 hose reel'
),
(
    'Blue Wave Resort',
    21.4200,
    92.0050,
    '4 extinguishers'
),
(
    'Mermaid Eco Resort',
    21.4280,
    92.0180,
    '2 extinguishers, 2 fire blankets'
);

COMMIT;

-- Every risk-zone row should report is_valid = true.
SELECT id, name, risk_level, ST_IsValid(boundary) AS is_valid
FROM risk_zones
ORDER BY id;

-- Generated resort locations should be populated.
SELECT id, name, lat, lng, fire_equipment,
       ST_AsText(location::geometry) AS generated_location
FROM resorts
ORDER BY id;
