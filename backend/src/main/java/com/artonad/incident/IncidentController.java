package com.artonad.incident;

import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/incidents")
public class IncidentController {

    private final IncidentService service;

    public IncidentController(IncidentService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<IncidentResponse> create(@Valid @RequestBody CreateIncidentRequest request) {
        Long reporterId = null; // Day 8: replace with the logged-in user's id from Dev2's JWT
        IncidentResponse created = service.create(request, reporterId);
        return ResponseEntity.created(URI.create("/incidents/" + created.id())).body(created);
    }

    @GetMapping
    public List<IncidentResponse> list() {
        return service.listAll();
    }

    @GetMapping("/{id}")
    public IncidentResponse get(@PathVariable long id) {
        return service.getById(id);
    }
}