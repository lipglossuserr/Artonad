package com.artonad.incident;

import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class IncidentService {

    private final IncidentRepository repository;

    public IncidentService(IncidentRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public IncidentResponse create(CreateIncidentRequest request, Long reporterId) {
        Severity severity = SeverityRules.compute(request.type(), request.peopleCount());

        long id = repository.insert(
                request.type(),
                severity,
                request.peopleCount(),
                cleanNote(request.note()),
                request.location().lat(),
                request.location().lng(),
                reporterId);

        // Phase 4: zone + resort tagging goes here.

        return getById(id);
    }

    @Transactional(readOnly = true)
    public IncidentResponse getById(long id) {
        // Phase 5: add recommendations here.
        return repository.findById(id).orElseThrow(() -> new IncidentNotFoundException(id));
    }

    @Transactional(readOnly = true)
    public List<IncidentResponse> listAll() {
        // Phase 5: add recommendations here too.
        return repository.findAllNewestFirst();
    }

    private static String cleanNote(String note) {
        return (note == null || note.isBlank()) ? null : note.trim();
    }
}