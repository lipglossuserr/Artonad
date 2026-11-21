-- DEV ONLY (Dev1's own test data). The real seed is N2's /seed/zones_resorts.sql.
-- CASCADE also empties incidents, because they reference zones/resorts.
TRUNCATE risk_zones, resorts RESTART IDENTITY CASCADE;

-- Insert order matters: the MEDIUM zone gets id 1 and the HIGH zone id 2,
-- so a lazy "first match wins" query would pick the wrong one in the overlap.
INSERT INTO risk_zones (name, risk_level, boundary) VALUES
                                                        ('Central Beach Medium', 'MEDIUM', ST_SetSRID(ST_GeomFromGeoJSON(
                                                                                                              '{"type":"Polygon","coordinates":[[[92.007,21.428],[92.013,21.428],[92.013,21.433],[92.007,21.433],[92.007,21.428]]]}'), 4326)),
                                                        ('North Beach High-Risk', 'HIGH', ST_SetSRID(ST_GeomFromGeoJSON(
                                                                                                             '{"type":"Polygon","coordinates":[[[92.003,21.426],[92.009,21.426],[92.009,21.431],[92.003,21.431],[92.003,21.426]]]}'), 4326)),
                                                        ('South Beach Low', 'LOW', ST_SetSRID(ST_GeomFromGeoJSON(
                                                                                                      '{"type":"Polygon","coordinates":[[[92.003,21.415],[92.009,21.415],[92.009,21.420],[92.003,21.420],[92.003,21.415]]]}'), 4326));

INSERT INTO resorts (name, lat, lng, fire_equipment) VALUES
                                                         ('Sea Pearl Resort', 21.4310, 92.0070, '2 extinguishers, 1 hose reel'),
                                                         ('Blue Wave Resort', 21.4200, 92.0050, '4 extinguishers');