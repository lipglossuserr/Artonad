package com.artonad.incident;

import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;

/**
 * Role rules (POST = TOURIST, GET list = ADMIN, GET one = both) live in Dev2's SecurityConfig.
 * The only rule enforced here is ownership: a tourist can read only incidents they reported.
 */
@RestController
@RequestMapping("/api/v1/incidents")
public class IncidentController {

    private final IncidentService service;

    public IncidentController(IncidentService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<IncidentResponse> create(@Valid @RequestBody CreateIncidentRequest request,
                                                   Authentication authentication) {
        IncidentResponse created = service.create(request, userId(authentication));
        return ResponseEntity.created(URI.create("/api/v1/incidents/" + created.id())).body(created);
    }

    @GetMapping
    public List<IncidentResponse> list() {
        return service.listAll();
    }

    @GetMapping("/{id}")
    public IncidentResponse get(@PathVariable long id, Authentication authentication) {
        return service.getForUser(id, userId(authentication), isAdmin(authentication));
    }

    /** Dev2's JwtAuthenticationFilter stores the user id (a Long) as the principal. */
    private static Long userId(Authentication authentication) {
        return (Long) authentication.getPrincipal();
    }

    private static boolean isAdmin(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }
}