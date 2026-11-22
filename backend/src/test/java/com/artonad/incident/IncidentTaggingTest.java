package com.artonad.incident;

import com.artonad.incident.dto.IncidentResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class IncidentTaggingTest extends AbstractPostgisTest {

    // ---------- zone tagging ----------

    @Test
    void incidentInsideAZoneGetsThatZone() {
        long zoneId = insertZone("North Beach", "HIGH", 92.003, 21.426, 92.009, 21.431);

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.zone()).isNotNull();
        assertThat(result.zone().id()).isEqualTo(zoneId);
        assertThat(result.zone().name()).isEqualTo("North Beach");
    }

    @Test
    void incidentOutsideEveryZoneHasNullZone() {
        insertZone("Far Away Zone", "HIGH", 92.100, 21.500, 92.110, 21.510);

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.zone()).isNull();
    }

    /** Run twice (HIGH inserted first / second) so the result cannot depend on insertion order or id. */
    @ParameterizedTest(name = "HIGH inserted first = {0}")
    @ValueSource(booleans = {true, false})
    void overlappingZonesPickTheHighestRisk(boolean highInsertedFirst) {
        long high;
        long medium;
        if (highInsertedFirst) {
            high = insertZone("High", "HIGH", 92.005, 21.426, 92.012, 21.431);
            medium = insertZone("Medium", "MEDIUM", 92.003, 21.426, 92.009, 21.431);
        } else {
            medium = insertZone("Medium", "MEDIUM", 92.003, 21.426, 92.009, 21.431);
            high = insertZone("High", "HIGH", 92.005, 21.426, 92.012, 21.431);
        }
        // The sample point (lng 92.0058) lies inside BOTH rectangles.

        IncidentResponse result = report(IncidentType.FIRE);

        assertThat(result.zone().id()).isEqualTo(high).isNotEqualTo(medium);
    }

    @Test
    void overlappingZonesOfEqualRiskPickTheLowestId() {
        long first = insertZone("Medium A", "MEDIUM", 92.003, 21.426, 92.009, 21.431);
        insertZone("Medium B", "MEDIUM", 92.005, 21.426, 92.012, 21.431);

        IncidentResponse result = report(IncidentType.FIRE);

        assertThat(result.zone().id()).isEqualTo(first);
    }

    // ---------- resort tagging ----------

    @Test
    void resortWithinTwoKmIsReturnedWithDistanceInMeters() {
        long resortId = insertResort("Sea Pearl", north(15));   // about 1660 m away

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.nearestResort()).isNotNull();
        assertThat(result.nearestResort().id()).isEqualTo(resortId);
        assertThat((double) result.nearestResort().distanceM())
                .isCloseTo(15 * METERS_PER_THOUSANDTH_DEG, within(20.0));
    }

    @Test
    void resortBeyondTwoKmIsNull() {
        insertResort("Too Far Resort", north(25));               // about 2770 m away

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.nearestResort()).isNull();
    }

    @Test
    void nearestOfSeveralResortsIsChosen() {
        insertResort("Farther Resort", north(15));               // inserted first on purpose
        long nearId = insertResort("Nearer Resort", north(5));   // about 554 m

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.nearestResort().id()).isEqualTo(nearId);
        assertThat(result.nearestResort().name()).isEqualTo("Nearer Resort");
    }

    // ---------- persistence and the all-empty case ----------

    @Test
    void tagsArePersistedAndReturnedOnLaterReads() {
        insertZone("North Beach", "HIGH", 92.003, 21.426, 92.009, 21.431);
        insertResort("Sea Pearl", north(4));

        IncidentResponse created = report(IncidentType.DROWNING);
        IncidentResponse reread = service.getById(created.id());

        assertThat(reread.zone()).isNotNull().isEqualTo(created.zone());
        assertThat(reread.nearestResort()).isNotNull().isEqualTo(created.nearestResort());
    }

    @Test
    void emptyDatabaseGivesNullZoneNullResortAndEmptyList() {
        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.zone()).isNull();
        assertThat(result.nearestResort()).isNull();
        assertThat(result.recommendedResponders()).isNotNull().isEmpty();
    }
}