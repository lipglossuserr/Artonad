
import type { IncidentDetail } from "../types/incident";

type Props = {
  incident: IncidentDetail | null;
};

function IncidentDetails({ incident }: Props) {
  if (!incident) {
    return <p>Select an incident marker to view details.</p>;
  }

  return (
    <div
      style={{
        padding: "20px",
        background: "white",
        borderRadius: "10px",
        marginTop: "20px",
      }}
    >
      <h2>Incident #{incident.id}</h2>

      <p><strong>Type:</strong> {incident.type}</p>
      <p><strong>Severity:</strong> {incident.severity}</p>
      <p><strong>Status:</strong> {incident.status}</p>
      <p><strong>People affected:</strong> {incident.peopleCount}</p>
      <p><strong>Description:</strong> {incident.note || "Not provided"}</p>

      <h3>Risk Zone</h3>
      <p>{incident.zone?.name || "No risk zone identified"}</p>

      <h3>Nearest Resort</h3>
      <p>
        {incident.nearestResort
          ? `${incident.nearestResort.name} (${incident.nearestResort.distanceM} m)`
          : "No nearby resort identified"}
      </p>

      <h3>Recommended Responders</h3>

      {incident.recommendedResponders?.length ? (
        incident.recommendedResponders.map((responder) => (
          <p key={responder.id}>
            {responder.name} — {responder.role} — {responder.distanceM} m
          </p>
        ))
      ) : (
        <p>No suitable responders available.</p>
      )}
    </div>
  );
}

export default IncidentDetails;
