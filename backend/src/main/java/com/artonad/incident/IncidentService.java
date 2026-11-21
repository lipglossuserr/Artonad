package com.artonad.incident;

import com.artonad.incident.SpatialRepository.ResortHit;
import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class IncidentService {

    /** Contract: the nearest resort is returned only if it is within 2 km. */
    static final double RESORT_MAX_DISTANCE_M = 2000;

    private final IncidentRepository repository;
    private final SpatialRepository spatial;

    public IncidentService(IncidentRepository repository, SpatialRepository spatial) {
        this.repository = repository;
        this.spatial = spatial;
    }

    @Transactional
    public IncidentResponse create(CreateIncidentRequest request, Long reporterId) {
        Severity severity = SeverityRules.compute(request.type(), request.peopleCount());
        double lat = request.location().lat();
        double lng = request.location().lng();

        long id = repository.insert(
                request.type(), severity, request.peopleCount(),
                cleanNote(request.note()), lat, lng, reporterId);

        // Tagging: which zone is this point in, and which resort is nearest?
        Long zoneId = spatial.findZoneIdAt(lat, lng).orElse(null);
        ResortHit resort = spatial.findNearestResort(lat, lng, RESORT_MAX_DISTANCE_M).orElse(null);
        repository.updateTags(id, zoneId,
                resort == null ? null : resort.id(),
                resort == null ? null : resort.distanceM());

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