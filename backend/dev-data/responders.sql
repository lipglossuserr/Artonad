-- DEV ONLY (Dev1's own test data). The real seed is N1's /seed/responders.sql.
TRUNCATE responders RESTART IDENTITY;

INSERT INTO responders (name, role, available, lat, lng) VALUES
                                                             ('Rahim',  'LIFEGUARD',   TRUE,  21.4290, 92.0040),
                                                             ('Karim',  'LIFEGUARD',   TRUE,  21.4265, 92.0068),
                                                             ('Salma',  'LIFEGUARD',   TRUE,  21.4250, 92.0030),
                                                             ('Tariq',  'LIFEGUARD',   TRUE,  21.4310, 92.0100),
                                                             ('Imran',  'LIFEGUARD',   FALSE, 21.4273, 92.0059),  -- UNAVAILABLE, ~15 m from the sample drowning point
                                                             ('Nasrin', 'FIREFIGHTER', TRUE,  21.4271, 92.0057),  -- wrong role for drowning, yet closer than any lifeguard
                                                             ('Jamal',  'FIREFIGHTER', TRUE,  21.4305, 92.0072),
                                                             ('Farhan', 'FIREFIGHTER', TRUE,  21.4200, 92.0050),
                                                             ('Mitu',   'FIREFIGHTER', TRUE,  21.4330, 92.0120),
                                                             ('Sohel',  'FIREFIGHTER', FALSE, 21.4272, 92.0060);  -- UNAVAILABLE