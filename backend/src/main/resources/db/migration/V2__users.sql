
-- V2__users.sql (owner: Dev2)
-- Authentication users for Sprint 1

CREATE TABLE app_user (
    user_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(255) UNIQUE,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,

    CONSTRAINT chk_app_user_role
        CHECK (role IN ('TOURIST', 'ADMIN'))
);

-- Connect incidents to the reporting user
ALTER TABLE incidents
ADD CONSTRAINT fk_incidents_reporter
FOREIGN KEY (reporter_id)
REFERENCES app_user(user_id);
