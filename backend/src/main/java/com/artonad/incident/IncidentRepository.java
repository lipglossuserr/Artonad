package com.artonad.incident;

import com.artonad.incident.dto.IncidentResponse;
import com.artonad.incident.dto.IncidentResponse.ResortRef;
import com.artonad.incident.dto.IncidentResponse.ZoneRef;
import com.artonad.incident.dto.LocationDto;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

@Repository
public class IncidentRepository {

    // LEFT JOIN, not JOIN: an incident with no zone / no resort must still be returned.
    private static final String SELECT_INCIDENT = """
            SELECT i.id, i.type, i.severity, i.people_count, i.note, i.lat, i.lng,
                   i.status, i.created_at,
                   i.zone_id, z.name AS zone_name,
                   i.nearest_resort_id, r.name AS resort_name, i.nearest_resort_distance_m
            FROM incidents i
            LEFT JOIN risk_zones z ON z.id = i.zone_id
            LEFT JOIN resorts r    ON r.id = i.nearest_resort_id
            """;

    private final JdbcClient jdbc;

    public IncidentRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** Inserts the incident (status defaults to REPORTED in the DB) and returns the new id. */
    public long insert(IncidentType type, Severity severity, int peopleCount,
                       String note, double lat, double lng, Long reporterId) {
        return jdbc.sql("""
                        INSERT INTO incidents (type, severity, people_count, note, lat, lng, reporter_id)
                        VALUES (:type, :severity, :peopleCount, :note, :lat, :lng, :reporterId)
                        RETURNING id
                        """)
                .param("type", type.name())
                .param("severity", severity.name())
                .param("peopleCount", peopleCount)
                .param("note", note, Types.VARCHAR)          // may be null
                .param("lat", lat)
                .param("lng", lng)
                .param("reporterId", reporterId, Types.BIGINT) // may be null until Dev2's auth is merged
                .query(Long.class)
                .single();
    }

    public Optional<IncidentResponse> findById(long id) {
        return jdbc.sql(SELECT_INCIDENT + " WHERE i.id = :id")
                .param("id", id)
                .query(this::mapRow)
                .optional();
    }

    public List<IncidentResponse> findAllNewestFirst() {
        return jdbc.sql(SELECT_INCIDENT + " ORDER BY i.created_at DESC, i.id DESC")
                .query(this::mapRow)
                .list();
    }
    /** Stores the tagging results. Null values are fine (outside every zone / no resort within 2 km). */
    public void updateTags(long incidentId, Long zoneId, Long resortId, Integer resortDistanceM) {
        jdbc.sql("""
                        UPDATE incidents
                        SET zone_id = :zoneId,
                            nearest_resort_id = :resortId,
                            nearest_resort_distance_m = :distanceM
                        WHERE id = :id
                        """)
                .param("zoneId", zoneId, Types.BIGINT)
                .param("resortId", resortId, Types.BIGINT)
                .param("distanceM", resortDistanceM, Types.INTEGER)
                .param("id", incidentId)
                .update();
    }
    /** True when the incident exists and was reported by this user. */
    public boolean isReportedBy(long incidentId, long userId) {
        return jdbc.sql("""
                        SELECT EXISTS (SELECT 1 FROM incidents
                                       WHERE id = :id AND reporter_id = :userId)
                        """)
                .param("id", incidentId)
                .param("userId", userId)
                .query(Boolean.class)
                .single();
    }


    private IncidentResponse mapRow(ResultSet rs, int rowNum) throws SQLException {
        Long zoneId = rs.getObject("zone_id", Long.class);
        ZoneRef zone = (zoneId == null) ? null : new ZoneRef(zoneId, rs.getString("zone_name"));

        Long resortId = rs.getObject("nearest_resort_id", Long.class);
        ResortRef resort = (resortId == null) ? null
                : new ResortRef(resortId, rs.getString("resort_name"), rs.getInt("nearest_resort_distance_m"));



        return new IncidentResponse(
                rs.getLong("id"),
                IncidentType.valueOf(rs.getString("type")),
                Severity.valueOf(rs.getString("severity")),
                rs.getInt("people_count"),
                rs.getString("note"),
                new LocationDto(rs.getDouble("lat"), rs.getDouble("lng")),
                IncidentStatus.valueOf(rs.getString("status")),
                zone,
                resort,
                List.of(), // Phase 5 fills this in
                rs.getObject("created_at", OffsetDateTime.class).toInstant().truncatedTo(ChronoUnit.SECONDS));
    }
}