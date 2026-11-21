package com.artonad.incident.dto;

import com.artonad.incident.IncidentType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Body of POST /incidents. Severity is NOT here: the backend decides it. */
public record CreateIncidentRequest(
        @NotNull(message = "type is required")
        IncidentType type,

        @NotNull(message = "peopleCount is required")
        @Min(value = 1, message = "peopleCount must be at least 1")
        Integer peopleCount,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        @NotNull(message = "location is required")
        @Valid
        LocationDto location) {
}