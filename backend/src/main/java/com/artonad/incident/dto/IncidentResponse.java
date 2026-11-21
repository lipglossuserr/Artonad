package com.artonad.incident.dto;

import com.artonad.incident.IncidentStatus;
import com.artonad.incident.IncidentType;
import com.artonad.incident.Severity;

import java.time.Instant;
import java.util.List;

/** Contract shape for POST /incidents, GET /incidents and GET /incidents/{id}. */
public record IncidentResponse(
        long id,
        IncidentType type,
        Severity severity,
        int peopleCount,
        String note,
        LocationDto location,
        IncidentStatus status,
        ZoneRef zone,                              // may be null
        ResortRef nearestResort,                   // may be null
        List<ResponderRef> recommendedResponders,  // may be empty, never null
        Instant createdAt) {

    public record ZoneRef(long id, String name) {}

    public record ResortRef(long id, String name, int distanceM) {}

    public record ResponderRef(long id, String name, String role, int distanceM) {}

    /** Records are immutable, so "changing" a field means making a copy. Used in Phase 5. */
    public IncidentResponse withRecommendedResponders(List<ResponderRef> responders) {
        return new IncidentResponse(id, type, severity, peopleCount, note, location,
                status, zone, nearestResort, responders, createdAt);
    }
}