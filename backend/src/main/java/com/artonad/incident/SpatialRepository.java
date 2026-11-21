package com.artonad.incident;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/** Every PostGIS query of Sprint 1 lives here, so it is easy to review and explain. */
@Repository
public class SpatialRepository {

    public record ResortHit(long id, int distanceM) {}

    private final JdbcClient jdbc;

    public SpatialRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Zone tagging. ST_MakePoint takes (lng, lat). SRID 4326 = WGS84 (GPS coordinates).
     * If zones overlap, the highest risk level wins; ties go to the lowest id (deterministic).
     */
    public Optional<Long> findZoneIdAt(double lat, double lng) {
        return jdbc.sql("""
                        SELECT id
                        FROM risk_zones
                        WHERE ST_Contains(boundary, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))
                        ORDER BY CASE risk_level WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 2 ELSE 1 END DESC,
                                 id
                        LIMIT 1
                        """)
                .param("lat", lat)
                .param("lng", lng)
                .query(Long.class)
                .optional();
    }

    /**
     * Nearest resort within maxMeters. Casting the point to geography makes ST_Distance and
     * ST_DWithin work in METERS. ST_DWithin keeps only resorts inside the limit (and can use
     * the spatial index); ORDER BY ... LIMIT 1 then picks the closest of those.
     */
    public Optional<ResortHit> findNearestResort(double lat, double lng, double maxMeters) {
        return jdbc.sql("""
                        SELECT r.id,
                               ROUND(ST_Distance(r.location, pt.g))::int AS distance_m
                        FROM resorts r
                        CROSS JOIN (SELECT ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography AS g) pt
                        WHERE ST_DWithin(r.location, pt.g, :maxMeters)
                        ORDER BY ST_Distance(r.location, pt.g)
                        LIMIT 1
                        """)
                .param("lat", lat)
                .param("lng", lng)
                .param("maxMeters", maxMeters)
                .query((rs, rowNum) -> new ResortHit(rs.getLong("id"), rs.getInt("distance_m")))
                .optional();
    }
}