package com.artonad.backend.zone;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class ZoneService {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public ZoneService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public Map<String, Object> getZones() {

        List<Map<String, Object>> features = jdbcTemplate.query(
            """
            SELECT id, name, risk_level,
                   ST_AsGeoJSON(boundary) AS geometry
            FROM risk_zones
            ORDER BY id
            """,
            (rs, rowNum) -> {
                Map<String, Object> properties = new LinkedHashMap<>();
                properties.put("id", rs.getLong("id"));
                properties.put("name", rs.getString("name"));
                properties.put("riskLevel", rs.getString("risk_level"));

                Map<String, Object> feature = new LinkedHashMap<>();
                feature.put("type", "Feature");

                try {
                    feature.put("geometry",
                        objectMapper.readTree(rs.getString("geometry")));
                } catch (Exception e) {
                    throw new IllegalStateException(
                        "Invalid risk zone geometry", e);
                }

                feature.put("properties", properties);
                return feature;
            }
        );

        Map<String, Object> zones = new LinkedHashMap<>();
        zones.put("type", "FeatureCollection");
        zones.put("features", features);

        List<Map<String, Object>> resorts = jdbcTemplate.query(
            """
            SELECT id, name, lat, lng, fire_equipment
            FROM resorts
            ORDER BY id
            """,
            (rs, rowNum) -> {
                Map<String, Object> location = new LinkedHashMap<>();
                location.put("lat", rs.getDouble("lat"));
                location.put("lng", rs.getDouble("lng"));

                Map<String, Object> resort = new LinkedHashMap<>();
                resort.put("id", rs.getLong("id"));
                resort.put("name", rs.getString("name"));
                resort.put("location", location);
                resort.put("fireEquipment", rs.getString("fire_equipment"));

                return resort;
            }
        );

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("zones", zones);
        response.put("resorts", resorts);

        return response;
    }
}
