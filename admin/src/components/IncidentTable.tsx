import type { ReactElement } from "react";

export interface IncidentLocation {
  lat: number;
  lng: number;
}

export interface IncidentZone {
  id: number;
  name: string;
}

export interface IncidentResort {
  id: number;
  name: string;
  distanceM?: number | null;
}

export interface RecommendedResponder {
  id: number;
  name: string;
  role: string;
  distanceM?: number | null;
}

/** Matches the Incident schema in contract/openapi.yaml. */
export interface Incident {
  id: number;
  type: "FIRE" | "DROWNING";
  severity: "LOW" | "MEDIUM" | "HIGH";
  peopleCount: number;
  note?: string | null;
  location: IncidentLocation;
  status: "REPORTED" | "ASSIGNED" | "ACCEPTED" | "DECLINED" | "RESOLVED";
  zone?: IncidentZone | null;
  nearestResort?: IncidentResort | null;
  recommendedResponders: RecommendedResponder[];
  createdAt: string;
}

interface IncidentTableProps {
  incidents: Incident[];
  onSelectIncident?: (incident: Incident) => void;
}

function formatDate(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Invalid date" : date.toLocaleString();
}

function formatDistance(distanceM?: number | null): string {
  return distanceM == null ? "—" : `${distanceM} m`;
}

/**
 * Presentational admin table.
 * The parent component is responsible for fetching /api/v1/incidents and
 * passing the returned array in through the incidents prop.
 */
export default function IncidentTable({
  incidents,
  onSelectIncident,
}: IncidentTableProps): ReactElement {
  if (incidents.length === 0) {
    return (
      <div className="incident-table__empty" role="status">
        No incidents have been reported.
      </div>
    );
  }

  return (
    <div className="incident-table__container">
      <table className="incident-table">
        <thead>
          <tr>
            <th scope="col">ID</th>
            <th scope="col">Type</th>
            <th scope="col">Severity</th>
            <th scope="col">People</th>
            <th scope="col">Zone</th>
            <th scope="col">Status</th>
            <th scope="col">Nearest resort</th>
            <th scope="col">Location</th>
            <th scope="col">Reported</th>
          </tr>
        </thead>
        <tbody>
          {incidents.map((incident) => {
            const row = (
              <>
                <td>{incident.id}</td>
                <td>{incident.type}</td>
                <td>
                  <span className={`incident-severity incident-severity--${incident.severity.toLowerCase()}`}>
                    {incident.severity}
                  </span>
                </td>
                <td>{incident.peopleCount}</td>
                <td>{incident.zone?.name ?? "Unassigned"}</td>
                <td>{incident.status}</td>
                <td>
                  {incident.nearestResort
                    ? `${incident.nearestResort.name} (${formatDistance(incident.nearestResort.distanceM)})`
                    : "—"}
                </td>
                <td>{incident.location.lat.toFixed(5)}, {incident.location.lng.toFixed(5)}</td>
                <td>{formatDate(incident.createdAt)}</td>
              </>
            );

            return (
              <tr
                key={incident.id}
                className={onSelectIncident ? "incident-table__row--selectable" : undefined}
                onClick={onSelectIncident ? () => onSelectIncident(incident) : undefined}
                onKeyDown={
                  onSelectIncident
                    ? (event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          onSelectIncident(incident);
                        }
                      }
                    : undefined
                }
                tabIndex={onSelectIncident ? 0 : undefined}
                aria-label={onSelectIncident ? `Open incident ${incident.id}` : undefined}
              >
                {row}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
