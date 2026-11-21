package com.artonad.incident;

import com.artonad.TestcontainersConfiguration;
import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import com.artonad.incident.dto.IncidentResponse.ResponderRef;
import com.artonad.incident.dto.LocationDto;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.util.List;

/**
 * Starts a real PostGIS container once (via TestcontainersConfiguration), runs Flyway V1 on it,
 * and wipes all tables before EVERY test so tests cannot influence each other.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
abstract class AbstractPostgisTest {

    /** The contract's sample incident point. */
    static final double LAT = 21.4272;
    static final double LNG = 92.0058;

    /** Moving 0.001 degrees of latitude is about 110.7 m here. Lets tests state distances simply. */
    static final double METERS_PER_THOUSANDTH_DEG = 110.7;

    @Autowired JdbcClient jdbc;
    @Autowired IncidentService service;

    @BeforeEach
    void cleanDatabase() {
        jdbc.sql("TRUNCATE incidents, responders, resorts, risk_zones RESTART IDENTITY CASCADE").update();
    }

    /** Latitude that is k thousandths of a degree north of the sample point (about k * 110.7 m). */
    static double north(int k) {
        return LAT + k * 0.001;
    }

    /** Rectangular zone. Argument order matches PostGIS: x = lng first, then y = lat. */
    long insertZone(String name, String riskLevel,
                    double minLng, double minLat, double maxLng, double maxLat) {
        return jdbc.sql("""
                        INSERT INTO risk_zones (name, risk_level, boundary)
                        VALUES (:name, :level, ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326))
                        RETURNING id
                        """)
                .param("name", name)
                .param("level", riskLevel)
                .param("minLng", minLng)
                .param("minLat", minLat)
                .param("maxLng", maxLng)
                .param("maxLat", maxLat)
                .query(Long.class)
                .single();
    }

    /** Resorts and responders sit on the same meridian as the sample point, so only latitude differs. */
    long insertResort(String name, double lat) {
        return jdbc.sql("INSERT INTO resorts (name, lat, lng) VALUES (:name, :lat, :lng) RETURNING id")
                .param("name", name)
                .param("lat", lat)
                .param("lng", LNG)
                .query(Long.class)
                .single();
    }

    long insertResponder(String name, String role, boolean available, double lat) {
        return jdbc.sql("""
                        INSERT INTO responders (name, role, available, lat, lng)
                        VALUES (:name, :role, :available, :lat, :lng)
                        RETURNING id
                        """)
                .param("name", name)
                .param("role", role)
                .param("available", available)
                .param("lat", lat)
                .param("lng", LNG)
                .query(Long.class)
                .single();
    }

    IncidentResponse report(IncidentType type, int peopleCount, double lat, double lng) {
        return service.create(
                new CreateIncidentRequest(type, peopleCount, null, new LocationDto(lat, lng)), null);
    }

    /** Report at the sample point with one person. */
    IncidentResponse report(IncidentType type) {
        return report(type, 1, LAT, LNG);
    }

    static List<String> names(IncidentResponse incident) {
        return incident.recommendedResponders().stream().map(ResponderRef::name).toList();
    }
}