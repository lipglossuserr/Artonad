-- CoastGuard 360 / Artonad - Dev6 zone and resort seed data
-- Development/demo data only. Do NOT run against production.
-- Assumes V1__init_schema.sql has already created risk_zones and resorts.
--
-- Draft redrawn around Dev5's supplied beach coverage envelopes:
--   Laboni:   lat 21.4256..21.4266, lng 91.9704..91.9719
--   Sugandha: lat 21.4206..21.4218, lng 91.9758..91.9772
--   Kolatoli: lat 21.4137..21.4148, lng 91.9825..91.9838
--
-- GeoJSON coordinates are [longitude, latitude], and every polygon ring is closed.
-- The two Laboni polygons intentionally overlap and have different risk levels.
-- The polygons are simple approximate envelopes, NOT surveyed shoreline boundaries.
-- Resort positions are provisional east-side (landward-intended) demo points;
-- confirm their actual land-side placement against a map before production use.
--
-- WARNING: TRUNCATE ... CASCADE also deletes incidents referencing these rows.
-- Use only with a disposable development database.

BEGIN;

TRUNCATE TABLE risk_zones, resorts RESTART IDENTITY CASCADE;

INSERT INTO risk_zones (name, risk_level, boundary) VALUES
(
    'Laboni Beach Medium',
    'MEDIUM',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[91.9699,21.4250],[91.9724,21.4250],[91.9724,21.4272],[91.9699,21.4272],[91.9699,21.4250]]]}'
        ),
        4326
    )
),
(
    'Laboni Beach High-Risk',
    'HIGH',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[91.9701,21.4252],[91.9722,21.4252],[91.9722,21.4270],[91.9701,21.4270],[91.9701,21.4252]]]}'
        ),
        4326
    )
),
(
    'Sugandha Beach Medium',
    'MEDIUM',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[91.9753,21.4200],[91.9777,21.4200],[91.9777,21.4224],[91.9753,21.4224],[91.9753,21.4200]]]}'
        ),
        4326
    )
),
(
    'Kolatoli Beach High-Risk',
    'HIGH',
    ST_SetSRID(
        ST_GeomFromGeoJSON(
            '{"type":"Polygon","coordinates":[[[91.9820,21.4131],[91.9843,21.4131],[91.9843,21.4154],[91.9820,21.4154],[91.9820,21.4131]]]}'
        ),
        4326
    )
);

INSERT INTO resorts (name, lat, lng, fire_equipment) VALUES
('Sea Pearl Resort', 21.4260, 91.9740, '2 extinguishers, 1 hose reel'),
('Blue Wave Resort', 21.4212, 91.9800, '4 extinguishers'),
('Mermaid Eco Resort', 21.4142, 91.9865, '2 extinguishers, 2 fire blankets');

COMMIT;

-- Basic geometry and generated-location checks
SELECT id, name, risk_level, ST_IsValid(boundary) AS is_valid
FROM risk_zones
ORDER BY id;

SELECT id, name, lat, lng, fire_equipment,
       ST_AsText(location::geometry) AS generated_location
FROM resorts
ORDER BY id;

-- The Laboni pair should overlap.
SELECT a.name AS zone_a, b.name AS zone_b,
       ST_Intersects(a.boundary, b.boundary) AS overlaps
FROM risk_zones a
JOIN risk_zones b ON a.id < b.id
WHERE ST_Intersects(a.boundary, b.boundary);
