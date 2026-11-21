package com.artonad.backend.zone;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ZoneServiceTest {

    @Test
    void shouldReturnEmptyZonesAndResorts() {

        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        ObjectMapper objectMapper = new ObjectMapper();

        when(jdbcTemplate.query(anyString(), any(org.springframework.jdbc.core.RowMapper.class)))
            .thenReturn(List.of());

        ZoneService zoneService = new ZoneService(jdbcTemplate, objectMapper);

        Map<String, Object> response = zoneService.getZones();

        Map<?, ?> zones = (Map<?, ?>) response.get("zones");

        assertEquals("FeatureCollection", zones.get("type"));
        assertEquals(List.of(), zones.get("features"));
        assertEquals(List.of(), response.get("resorts"));

        verify(jdbcTemplate, times(2))
            .query(anyString(), any(org.springframework.jdbc.core.RowMapper.class));
    }

    @Test
    void shouldReturnRiskZoneAsGeoJson() {

        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        ObjectMapper objectMapper = new ObjectMapper();

        when(jdbcTemplate.query(
            anyString(),
            any(org.springframework.jdbc.core.RowMapper.class)
        )).thenAnswer(invocation -> {

            String sql = invocation.getArgument(0);

            if (sql.contains("FROM resorts")) {
                return List.of();
            }

            org.springframework.jdbc.core.RowMapper<Map<String, Object>> mapper =
                invocation.getArgument(1);

            java.sql.ResultSet rs = mock(java.sql.ResultSet.class);

            when(rs.getLong("id")).thenReturn(1L);
            when(rs.getString("name")).thenReturn("Test Zone");
            when(rs.getString("risk_level")).thenReturn("HIGH");
            when(rs.getString("geometry")).thenReturn(
                "{\"type\":\"Polygon\",\"coordinates\":[[[90.4,23.7],[90.41,23.7],[90.41,23.71],[90.4,23.7]]]}"
            );

            return List.of(mapper.mapRow(rs, 0));
        });

        ZoneService service = new ZoneService(jdbcTemplate, objectMapper);

        Map<String, Object> response = service.getZones();
        Map<?, ?> zones = (Map<?, ?>) response.get("zones");
        List<?> features = (List<?>) zones.get("features");

        assertEquals("FeatureCollection", zones.get("type"));
        assertEquals(1, features.size());

        Map<?, ?> feature = (Map<?, ?>) features.get(0);
        Map<?, ?> properties = (Map<?, ?>) feature.get("properties");

        assertEquals("Feature", feature.get("type"));
        assertEquals("Test Zone", properties.get("name"));
        assertEquals("HIGH", properties.get("riskLevel"));
        assertEquals(
            "Polygon",
            ((com.fasterxml.jackson.databind.JsonNode) feature.get("geometry"))
                .get("type").asText()
        );

        assertEquals(List.of(), response.get("resorts"));
    }

    @Test
    void shouldReturnResortWithLocationAndFireEquipment() {

        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        ObjectMapper objectMapper = new ObjectMapper();

        when(jdbcTemplate.query(
            anyString(),
            any(org.springframework.jdbc.core.RowMapper.class)
        )).thenAnswer(invocation -> {

            String sql = invocation.getArgument(0);

            if (sql.contains("FROM risk_zones")) {
                return List.of();
            }

            org.springframework.jdbc.core.RowMapper<Map<String, Object>> mapper =
                invocation.getArgument(1);

            java.sql.ResultSet rs = mock(java.sql.ResultSet.class);

            when(rs.getLong("id")).thenReturn(1L);
            when(rs.getString("name")).thenReturn("Test Resort");
            when(rs.getDouble("lat")).thenReturn(21.4272);
            when(rs.getDouble("lng")).thenReturn(92.0058);
            when(rs.getString("fire_equipment"))
                .thenReturn("Fire extinguishers available");

            return List.of(mapper.mapRow(rs, 0));
        });

        ZoneService service = new ZoneService(jdbcTemplate, objectMapper);

        Map<String, Object> response = service.getZones();

        List<?> resorts = (List<?>) response.get("resorts");

        assertEquals(1, resorts.size());

        Map<?, ?> resort = (Map<?, ?>) resorts.get(0);
        Map<?, ?> location = (Map<?, ?>) resort.get("location");

        assertEquals(1L, resort.get("id"));
        assertEquals("Test Resort", resort.get("name"));
        assertEquals(21.4272, (Double) location.get("lat"), 0.000001);
        assertEquals(92.0058, (Double) location.get("lng"), 0.000001);
        assertEquals(
            "Fire extinguishers available",
            resort.get("fireEquipment")
        );

        Map<?, ?> zones = (Map<?, ?>) response.get("zones");
        assertEquals(List.of(), zones.get("features"));
    }
}
