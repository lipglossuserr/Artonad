package com.artonad.incident.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

public record LocationDto(
        @NotNull(message = "location.lat is required")
        @DecimalMin(value = "-90.0", message = "location.lat must be between -90 and 90")
        @DecimalMax(value = "90.0", message = "location.lat must be between -90 and 90")
        Double lat,

        @NotNull(message = "location.lng is required")
        @DecimalMin(value = "-180.0", message = "location.lng must be between -180 and 180")
        @DecimalMax(value = "180.0", message = "location.lng must be between -180 and 180")
        Double lng) {
}