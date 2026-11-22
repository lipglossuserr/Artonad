
-- =====================================================
-- ARTONAD / COASTGUARD 360
-- Dev5: Responder seed data
-- Demo area: Cox's Bazar, Bangladesh
-- Total responders: 20
-- Lifeguards: 10
-- Firefighters: 10
-- Unavailable: 3
-- =====================================================

-- LOCAL DEVELOPMENT DATABASE ONLY.
-- This clears existing responder records and resets IDs.
TRUNCATE responders RESTART IDENTITY;

INSERT INTO responders
(name, role, available, lat, lng)
VALUES

-- LABONI BEACH: 4 LIFEGUARDS, 3 FIREFIGHTERS
('Rahim Ahmed',       'LIFEGUARD',   TRUE,  21.42630, 91.97090),
('Karim Hossain',     'LIFEGUARD',   TRUE,  21.42600, 91.97130),
('Tanvir Islam',      'LIFEGUARD',   TRUE,  21.42655, 91.97155),
('Saif Uddin',        'LIFEGUARD',   FALSE, 21.42580, 91.97070),
('Arif Hasan',        'FIREFIGHTER', TRUE,  21.42640, 91.97190),
('Imran Kabir',       'FIREFIGHTER', TRUE,  21.42565, 91.97120),
('Mahmud Rahman',     'FIREFIGHTER', TRUE,  21.42610, 91.97040),

-- SUGANDHA BEACH: 3 LIFEGUARDS, 4 FIREFIGHTERS
('Rafiq Ahmed',       'LIFEGUARD',   TRUE,  21.42150, 91.97610),
('Shakil Islam',      'LIFEGUARD',   TRUE,  21.42110, 91.97655),
('Nayeem Hasan',      'LIFEGUARD',   TRUE,  21.42175, 91.97690),
('Farhan Ahmed',      'FIREFIGHTER', TRUE,  21.42085, 91.97620),
('Sabbir Hossain',    'FIREFIGHTER', FALSE, 21.42135, 91.97715),
('Faisal Rahman',     'FIREFIGHTER', TRUE,  21.42060, 91.97670),
('Mehedi Hasan',      'FIREFIGHTER', TRUE,  21.42100, 91.97585),

-- KOLATOLI BEACH: 3 LIFEGUARDS, 3 FIREFIGHTERS
('Ashraful Islam',    'LIFEGUARD',   TRUE,  21.41465, 91.98290),
('Abdullah Khan',     'LIFEGUARD',   TRUE,  21.41420, 91.98335),
('Saad Rahman',       'LIFEGUARD',   TRUE,  21.41390, 91.98375),
('Rakib Hossain',     'FIREFIGHTER', TRUE,  21.41480, 91.98360),
('Nasir Uddin',       'FIREFIGHTER', FALSE, 21.41370, 91.98285),
('Faisal Ahmed',      'FIREFIGHTER', TRUE,  21.41440, 91.98250);
