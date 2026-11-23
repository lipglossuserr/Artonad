export interface IncidentSummary {
  id: number;
  type: "FIRE" | "DROWNING";
  severity: "LOW" | "MEDIUM" | "HIGH";
  status: string;
  location: {
    lat: number;
    lng: number;
  };
  createdAt: string;
}

export interface IncidentDetail extends IncidentSummary {
  peopleCount: number;
  note: string | null;
  zone: {
    id: number;
    name: string;
  } | null;
  nearestResort: {
    id: number;
    name: string;
    distanceM: number;
  } | null;
  recommendedResponders: {
    id: number;
    name: string;
    role: string;
    distanceM: number;
  }[];
}