package com.artonad.backend.zone;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/zones")
public class ZoneController {

    @GetMapping
    public ResponseEntity<Map<String, Object>> getZones() {

        Map<String, Object> geoJson = Map.of(
            "type", "FeatureCollection",
            "features", List.of()
        );

        return ResponseEntity.ok(geoJson);
    }
}
