package com.artonad.incident;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SeverityRulesTest {

    @ParameterizedTest
    @CsvSource({
            "DROWNING, 1,  HIGH",
            "DROWNING, 2,  HIGH",
            "DROWNING, 3,  HIGH",
            "FIRE,     1,  MEDIUM",
            "FIRE,     2,  MEDIUM",
            "FIRE,     3,  HIGH",
            "FIRE,     10, HIGH"
    })
    void severityFollowsContractRule(IncidentType type, int people, Severity expected) {
        assertEquals(expected, SeverityRules.compute(type, people));
    }
}