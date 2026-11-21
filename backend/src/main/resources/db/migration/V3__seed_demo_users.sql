
-- V3: Demo account for testing authentication

INSERT INTO app_user
    (name, username, password_hash, role)
VALUES
    (
        'Demo Tourist',
        'tourist1',
        '$2a$10$4TJgCeaOL8P8fb2phS6g9e8zjYsp0yZiOw7ZnNwGuUufA1wU58xia',
        'TOURIST'
    );
