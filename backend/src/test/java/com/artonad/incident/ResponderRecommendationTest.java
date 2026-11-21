package com.artonad.incident;

import com.artonad.incident.dto.IncidentResponse;
import com.artonad.incident.dto.IncidentResponse.ResponderRef;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/** Naming: LG-k is a lifeguard about k * 110 m from the sample point, FF-k a firefighter. */
class ResponderRecommendationTest extends AbstractPostgisTest {

    @Test
    void drowningPicksLifeguardsNotACloserFirefighter() {
        insertResponder("FF-closest", "FIREFIGHTER", true, LAT + 0.0005);   // about 55 m, closest of all
        insertResponder("LG-2", "LIFEGUARD", true, north(2));
        insertResponder("LG-1", "LIFEGUARD", true, north(1));

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(names(result)).containsExactly("LG-1", "LG-2");
        assertThat(result.recommendedResponders()).extracting(ResponderRef::role).containsOnly("LIFEGUARD");
    }

    @Test
    void firePicksFirefightersNotACloserLifeguard() {
        insertResponder("LG-closest", "LIFEGUARD", true, LAT + 0.0005);
        insertResponder("FF-1", "FIREFIGHTER", true, north(1));

        IncidentResponse result = report(IncidentType.FIRE);

        assertThat(names(result)).containsExactly("FF-1");
    }

    @Test
    void unavailableResponderNeverAppearsEvenIfClosest() {
        insertResponder("LG-1-busy", "LIFEGUARD", false, north(1));
        insertResponder("LG-2", "LIFEGUARD", true, north(2));

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(names(result)).containsExactly("LG-2");
    }

    @Test
    void returnsOnlyTheThreeNearestSortedNearestFirst() {
        // Inserted in scrambled order so the SQL ORDER BY has to do the work.
        insertResponder("LG-4", "LIFEGUARD", true, north(4));
        insertResponder("LG-2", "LIFEGUARD", true, north(2));
        insertResponder("LG-5", "LIFEGUARD", true, north(5));
        insertResponder("LG-1", "LIFEGUARD", true, north(1));
        insertResponder("LG-3", "LIFEGUARD", true, north(3));

        IncidentResponse result = report(IncidentType.DROWNING);

        List<ResponderRef> recommended = result.recommendedResponders();
        assertThat(names(result)).containsExactly("LG-1", "LG-2", "LG-3");
        assertThat(recommended).extracting(ResponderRef::distanceM).isSorted();
        assertThat((double) recommended.get(0).distanceM()).isCloseTo(METERS_PER_THOUSANDTH_DEG, within(15.0));
        assertThat((double) recommended.get(2).distanceM()).isCloseTo(3 * METERS_PER_THOUSANDTH_DEG, within(15.0));
    }

    @Test
    void fewerThanThreeSuitableRespondersReturnsWhatExists() {
        insertResponder("LG-1", "LIFEGUARD", true, north(1));

        assertThat(names(report(IncidentType.DROWNING))).containsExactly("LG-1");
    }

    @Test
    void noRespondersAtAllGivesAnEmptyListNotNull() {
        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.recommendedResponders()).isNotNull().isEmpty();
    }

    @Test
    void onlyUnavailableOrWrongRoleRespondersGivesAnEmptyList() {
        insertResponder("LG-busy", "LIFEGUARD", false, north(1));          // right role, unavailable
        insertResponder("FF-free", "FIREFIGHTER", true, north(2));         // available, wrong role

        IncidentResponse result = report(IncidentType.DROWNING);

        assertThat(result.recommendedResponders()).isNotNull().isEmpty();
    }

    @Test
    void recommendationsFollowCurrentAvailabilityOnEveryRead() {
        long nearest = insertResponder("LG-1", "LIFEGUARD", true, north(1));
        insertResponder("LG-2", "LIFEGUARD", true, north(2));
        insertResponder("LG-3", "LIFEGUARD", true, north(3));
        insertResponder("LG-4", "LIFEGUARD", true, north(4));
        IncidentResponse created = report(IncidentType.DROWNING);
        assertThat(names(created)).containsExactly("LG-1", "LG-2", "LG-3");

        jdbc.sql("UPDATE responders SET available = FALSE WHERE id = :id").param("id", nearest).update();

        assertThat(names(service.getById(created.id()))).containsExactly("LG-2", "LG-3", "LG-4");
    }

    @Test
    void listGivesEachIncidentItsOwnRecommendationsByType() {
        insertResponder("LG-1", "LIFEGUARD", true, north(1));
        insertResponder("LG-2", "LIFEGUARD", true, north(2));
        insertResponder("FF-1", "FIREFIGHTER", true, north(1));
        insertResponder("FF-2", "FIREFIGHTER", true, north(2));
        IncidentResponse drowning = report(IncidentType.DROWNING);
        IncidentResponse fire = report(IncidentType.FIRE);

        List<IncidentResponse> list = service.listAll();

        assertThat(list).extracting(IncidentResponse::id).containsExactly(fire.id(), drowning.id()); // newest first
        assertThat(names(list.get(0))).containsExactly("FF-1", "FF-2");
        assertThat(names(list.get(1))).containsExactly("LG-1", "LG-2");
    }

    @Test
    void listWithNoIncidentsIsEmpty() {
        assertThat(service.listAll()).isEmpty();
    }
}