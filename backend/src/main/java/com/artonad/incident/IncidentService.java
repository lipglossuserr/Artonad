package com.artonad.incident;

import com.artonad.incident.SpatialRepository.ResortHit;
import com.artonad.incident.dto.CreateIncidentRequest;
import com.artonad.incident.dto.IncidentResponse;
import com.artonad.incident.dto.IncidentResponse.ResponderRef;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

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

        return getById(id); // the response includes recommendations, like GET /incidents/{id}
    }

    /** Recommendations are computed on every read, so they reflect current availability. */
    @Transactional(readOnly = true)
    public IncidentResponse getById(long id) {
        IncidentResponse incident = repository.findById(id)
                .orElseThrow(() -> new IncidentNotFoundException(id));
        List<ResponderRef> recommended = spatial.recommendResponders(List.of(id))
                .getOrDefault(id, List.of());
        return incident.withRecommendedResponders(recommended);
    }
    /** Admins may read any incident; a tourist only their own (the contract allows a 403 here). */
    @Transactional(readOnly = true)
    public IncidentResponse getForUser(long id, long userId, boolean admin) {
        IncidentResponse incident = getById(id);   // a missing id is always a 404, never a 403
        if (!admin && !repository.isReportedBy(id, userId)) {
            throw new IncidentAccessDeniedException();
        }
        return incident;
    }

    @Transactional(readOnly = true)
    public List<IncidentResponse> listAll() {
        List<IncidentResponse> incidents = repository.findAllNewestFirst();
        Map<Long, List<ResponderRef>> recommended = spatial.recommendResponders(
                incidents.stream().map(IncidentResponse::id).toList());
        return incidents.stream()
                .map(i -> i.withRecommendedResponders(recommended.getOrDefault(i.id(), List.of())))
                .toList();
    }

    private static String cleanNote(String note) {
        return (note == null || note.isBlank()) ? null : note.trim();
    }
}