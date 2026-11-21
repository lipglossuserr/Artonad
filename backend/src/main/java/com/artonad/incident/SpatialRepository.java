package com.artonad.incident;

import com.artonad.incident.dto.IncidentResponse.ResponderRef;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/** Every PostGIS query of Sprint 1 lives here, so it is easy to review and explain. */
@Repository
public class SpatialRepository {

    public record ResortHit(long id, int distanceM) {}

    private record RecommendationRow(long incidentId, ResponderRef responder) {}

    /** Contract: return the top 3 nearest suitable responders. */
    static final int MAX_RECOMMENDATIONS = 3;

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

    /**
     * Recommendation for one or many incidents in a single query.
     * For each incident the LATERAL subquery runs once, sees that incident's type and location,
     * and keeps: available responders only, role matching the type, nearest first, top 3.
     * Incidents with no suitable responder simply have no entry in the returned map.
     */
    public Map<Long, List<ResponderRef>> recommendResponders(Collection<Long> incidentIds) {
        if (incidentIds.isEmpty()) {
            return Map.of();
        }
        List<RecommendationRow> rows = jdbc.sql("""
                        SELECT i.id AS incident_id, rr.id, rr.name, rr.role,
                               ROUND(rr.dist)::int AS distance_m
                        FROM incidents i
                        CROSS JOIN LATERAL (
                            SELECT r.id, r.name, r.role, ST_Distance(r.location, i.location) AS dist
                            FROM responders r
                            WHERE r.available = TRUE
                              AND r.role = CASE i.type WHEN 'DROWNING' THEN 'LIFEGUARD'
                                                       WHEN 'FIRE'     THEN 'FIREFIGHTER' END
                            ORDER BY dist, r.id
                            LIMIT :limit
                        ) rr
                        WHERE i.id IN (:ids)
                        ORDER BY i.id, rr.dist, rr.id
                        """)
                .param("limit", MAX_RECOMMENDATIONS)
                .param("ids", incidentIds)
                .query((rs, rowNum) -> new RecommendationRow(
                        rs.getLong("incident_id"),
                        new ResponderRef(rs.getLong("id"), rs.getString("name"),
                                rs.getString("role"), rs.getInt("distance_m"))))
                .list();

        // groupingBy keeps the encounter order inside each list, so "nearest first" survives.
        return rows.stream().collect(Collectors.groupingBy(
                RecommendationRow::incidentId,
                Collectors.mapping(RecommendationRow::responder, Collectors.toList())));
    }
}