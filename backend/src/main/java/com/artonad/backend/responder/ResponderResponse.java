package com.artonad.backend.responder;

public record ResponderResponse(
    Long id,
    String name,
    String role,
    boolean available,
    LocationResponse location
) {
    public record LocationResponse(
        double lat,
        double lng
    ) {}
}
