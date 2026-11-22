package com.artonad.incident;

import com.artonad.backend.security.JwtService;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Users tourist1 / admin1 come from Dev2's migrations V3 / V4. */
@AutoConfigureMockMvc
class IncidentApiSecurityTest extends AbstractPostgisTest {

    private static final String BODY = """
            {"type":"DROWNING","peopleCount":2,"note":"Child in water near rocks",
             "location":{"lat":21.4260,"lng":91.9710}}""";

    @Autowired MockMvc mockMvc;
    @Autowired JwtService jwtService;

    // ---------- helpers ----------

    private String bearer(long userId, String role) {
        return "Bearer " + jwtService.generateToken(userId, role);
    }

    private long userId(String username) {
        return jdbc.sql("SELECT user_id FROM app_user WHERE username = :u")
                .param("u", username).query(Long.class).single();
    }

    /** A second tourist, inserted once and reused (idempotent, so no cleanup needed). */
    private long otherTouristId() {
        return jdbc.sql("""
                        INSERT INTO app_user (name, username, password_hash, role)
                        VALUES ('Other Tourist', 'tourist2', 'not-a-real-hash', 'TOURIST')
                        ON CONFLICT (username) DO UPDATE SET name = EXCLUDED.name
                        RETURNING user_id
                        """)
                .query(Long.class).single();
    }

    private long createIncidentAs(String authorization) throws Exception {
        String json = mockMvc.perform(post("/api/v1/incidents")
                        .header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(json, "$.id")).longValue();
    }

    // ---------- 401: not logged in ----------

    @Test
    void requestsWithoutATokenGet401() throws Exception {
        mockMvc.perform(post("/api/v1/incidents").contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
        mockMvc.perform(get("/api/v1/incidents")).andExpect(status().isUnauthorized());
    }

    @Test
    void aGarbageTokenGets401() throws Exception {
        mockMvc.perform(get("/api/v1/incidents").header("Authorization", "Bearer not-a-real-token"))
                .andExpect(status().isUnauthorized());
    }

    // ---------- tourist creates ----------

    @Test
    void touristCreatesAnIncidentAndItIsStoredWithTheirUserId() throws Exception {
        long tourist = userId("tourist1");

        long id = createIncidentAs(bearer(tourist, "TOURIST"));

        Long reporter = jdbc.sql("SELECT reporter_id FROM incidents WHERE id = :id")
                .param("id", id).query(Long.class).single();
        assertThat(reporter).isEqualTo(tourist);
    }

    @Test
    void createdIncidentFollowsTheContractShape() throws Exception {
        mockMvc.perform(post("/api/v1/incidents")
                        .header("Authorization", bearer(userId("tourist1"), "TOURIST"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.type").value("DROWNING"))
                .andExpect(jsonPath("$.severity").value("HIGH"))
                .andExpect(jsonPath("$.peopleCount").value(2))
                .andExpect(jsonPath("$.status").value("REPORTED"))
                .andExpect(jsonPath("$.location.lat").value(21.426))
                .andExpect(jsonPath("$.location.lng").value(91.971))
                .andExpect(jsonPath("$.zone").value(nullValue()))             // empty DB: no zone
                .andExpect(jsonPath("$.nearestResort").value(nullValue()))    // empty DB: no resort
                .andExpect(jsonPath("$.recommendedResponders").isArray())
                .andExpect(jsonPath("$.createdAt").isString());
    }

    @Test
    void adminCannotCreateIncidents() throws Exception {
        mockMvc.perform(post("/api/v1/incidents")
                        .header("Authorization", bearer(userId("admin1"), "ADMIN"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    // ---------- listing is admin-only ----------

    @Test
    void listingIsAdminOnly() throws Exception {
        createIncidentAs(bearer(userId("tourist1"), "TOURIST"));

        mockMvc.perform(get("/api/v1/incidents")
                        .header("Authorization", bearer(userId("tourist1"), "TOURIST")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/incidents")
                        .header("Authorization", bearer(userId("admin1"), "ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    // ---------- ownership on read ----------

    @Test
    void touristReadsOwnIncidentButNotSomeoneElsesAndAdminReadsAll() throws Exception {
        long tourist = userId("tourist1");
        long other = otherTouristId();
        long id = createIncidentAs(bearer(tourist, "TOURIST"));

        mockMvc.perform(get("/api/v1/incidents/" + id).header("Authorization", bearer(tourist, "TOURIST")))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/incidents/" + id).header("Authorization", bearer(other, "TOURIST")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/incidents/" + id).header("Authorization", bearer(userId("admin1"), "ADMIN")))
                .andExpect(status().isOk());
    }

    @Test
    void unknownIncidentIs404NotForbidden() throws Exception {
        mockMvc.perform(get("/api/v1/incidents/999999")
                        .header("Authorization", bearer(userId("tourist1"), "TOURIST")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));
    }

    // ---------- the old unversioned route must stay gone ----------

    @Test
    void theOldUnversionedRouteNoLongerExists() throws Exception {
        mockMvc.perform(get("/incidents")
                        .header("Authorization", bearer(userId("tourist1"), "TOURIST")))
                .andExpect(status().isNotFound());
    }
}