
import type { IncidentSummary, IncidentDetail } from "../types/incident";

const API_BASE_URL = "http://localhost:8080/api/v1";

// Get all incidents for the map
export async function getIncidents(): Promise<IncidentSummary[]> {
  const token = localStorage.getItem("token");

  const response = await fetch(`${API_BASE_URL}/incidents`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to load incidents: ${response.status}`);
  }

  return response.json();
}

// Get full details of one incident
export async function getIncidentById(
  id: number
): Promise<IncidentDetail> {
  const token = localStorage.getItem("token");

  const response = await fetch(`${API_BASE_URL}/incidents/${id}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(
      `Failed to load incident details: ${response.status}`
    );
  }

  return response.json();
}
