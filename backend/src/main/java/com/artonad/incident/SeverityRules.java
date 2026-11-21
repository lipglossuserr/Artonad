package com.artonad.incident;

/** Contract rule: drowning = HIGH, fire = MEDIUM, either becomes HIGH when 3+ people are involved. */
public final class SeverityRules {

    private SeverityRules() {}

    public static Severity compute(IncidentType type, int peopleCount) {
        if (peopleCount >= 3) {
            return Severity.HIGH;
        }
        return switch (type) {
            case DROWNING -> Severity.HIGH;
            case FIRE -> Severity.MEDIUM;
        };
    }
}