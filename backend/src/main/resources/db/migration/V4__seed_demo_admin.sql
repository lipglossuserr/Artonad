
-- V4: Demo admin account for local testing

INSERT INTO app_user
    (name, username, password_hash, role)
VALUES
    (
        'Demo Admin',
        'admin1',
        '$2a$10$rvD99uNBrVN.k3BcTncwuuRdAxKQw97qXREIx9tylELsc4U1ZsBp.',
        'ADMIN'
    );
