-- STAND-IN dev data around N1's responders. N2's shoreline-shaped file replaces it.
TRUNCATE risk_zones, resorts RESTART IDENTITY CASCADE;

INSERT INTO risk_zones (name, risk_level, boundary) VALUES
                                                        ('Laboni Beach Medium',        'MEDIUM', ST_MakeEnvelope(91.969, 21.424, 91.974, 21.428,  4326)),
                                                        ('Laboni Swim Zone High-Risk', 'HIGH',   ST_MakeEnvelope(91.968, 21.425, 91.972, 21.4275, 4326)),  -- overlaps the one above
                                                        ('Sugandha Beach Low',         'LOW',    ST_MakeEnvelope(91.974, 21.419, 91.979, 21.423,  4326)),
                                                        ('Kolatoli Beach High-Risk',   'HIGH',   ST_MakeEnvelope(91.981, 21.412, 91.986, 21.416,  4326));

INSERT INTO resorts (name, lat, lng, fire_equipment) VALUES
                                                         ('Sea Pearl Resort',   21.4285, 91.9725, '2 extinguishers, 1 hose reel'),
                                                         ('Blue Wave Resort',   21.4195, 91.9790, '4 extinguishers'),
                                                         ('Mermaid Eco Resort', 21.4125, 91.9850, '2 extinguishers, 2 fire blankets');