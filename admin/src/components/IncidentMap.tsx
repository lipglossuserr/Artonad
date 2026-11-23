import L from "leaflet";
import { useEffect, useState } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  GeoJSON,
} from "react-leaflet";
import type { FeatureCollection } from "geojson";
import "leaflet/dist/leaflet.css";
import { getZones } from "../api/zones";
import { getIncidents } from "../api/incidents";
import type { IncidentSummary } from "../types/incident";
import { getIncidentById } from "../api/incidents";
import type { IncidentDetail } from "../types/incident";
import IncidentDetails from "./IncidentDetails";
import { getResponders } from "../api/responders";
import type { Responder } from "../api/responders";

type Resort = {
  id: number;
  name: string;
  location: {
    lat: number;
    lng: number;
  };
  fireEquipment?: string;
};

type ZonesResponse = {
  zones: FeatureCollection;
  resorts: Resort[];
};
function createIncidentIcon(
  type: "FIRE" | "DROWNING",
  severity: "LOW" | "MEDIUM" | "HIGH"
) {
  const color =
    severity === "HIGH"
      ? "#dc2626"
      : severity === "MEDIUM"
      ? "#f59e0b"
      : "#16a34a";

  const symbol = type === "FIRE" ? "🔥" : "🌊";

  return L.divIcon({
    className: "incident-marker",
    html: `
      <div style="
        background: ${color};
        width: 38px;
        height: 38px;
        border-radius: 50%;
        border: 3px solid white;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.3);
      ">
        ${symbol}
      </div>
    `,
    iconSize: [38, 38],
    iconAnchor: [19, 19],
  });
}
function IncidentMap() {
  const [data, setData] = useState<ZonesResponse | null>(null);
  const [error, setError] = useState("");
  const [selectedIncident, setSelectedIncident] =
  useState<IncidentDetail | null>(null);
  const [incidents, setIncidents] = useState<IncidentSummary[]>([]);
  const [responders, setResponders] = useState<Responder[]>([]);

  useEffect(() => {
  async function loadZones() {
    try {
      const result: ZonesResponse = await getZones();
      setData(result);
    } catch (error) {
      console.error("Error loading zones:", error);
      setError("Could not load zones and resorts.");
    }
  }

  loadZones();
}, []);

  useEffect(() => {
  async function loadIncidents() {
    try {
      const data = await getIncidents();
      setIncidents(data);
    } catch (error) {
      console.error("Error loading incidents:", error);
    }
  }

  loadIncidents();

  const interval = setInterval(loadIncidents, 5000);

  return () => clearInterval(interval);
}, []);
  
useEffect(() => {
  async function loadResponders() {
    try {
      const result = await getResponders();
      setResponders(result);
    } catch (error) {
      console.error("Error loading responders:", error);
    }
  }

  loadResponders();
  const interval = setInterval(loadResponders, 10000);

  return () => clearInterval(interval);
}, []);

  async function handleSelectIncident(id: number) {
  try {
    const details = await getIncidentById(id);
    setSelectedIncident(details);
  } catch (error) {
    console.error("Failed to load incident details:", error);
  }
}
  return (
    <div>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <MapContainer
        center={[21.4272, 92.0058]}
        zoom={13}
        style={{ height: "450px", width: "100%" }}
      >
        <TileLayer
          attribution="&copy; OpenStreetMap contributors"
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* Temporary incident marker */}
        {incidents.map((incident) => (
         <Marker
            key={incident.id}
            position={[
            incident.location.lat,
            incident.location.lng,
        ]}
        icon={createIncidentIcon(incident.type, incident.severity)}
        eventHandlers={{
            click: () => handleSelectIncident(incident.id),
        }}
        >
        <Popup>
            <strong>
                {incident.type === "FIRE" ? "🔥 Fire" : "🌊 Drowning"}
        </strong>
        <p>Incident ID: {incident.id}</p>
        <p>Severity: {incident.severity}</p>
        <p>Status: {incident.status}</p>
    </Popup>
  </Marker>
   ))}

     

{/* Responder markers */}
{responders
  .filter(
    (responder) =>
      responder.location &&
      Number.isFinite(responder.location.lat) &&
      Number.isFinite(responder.location.lng)
  )
  .map((responder) => (
    <Marker
      key={`responder-${responder.id}`}
      position={[
        responder.location.lat,
        responder.location.lng,
      ]}
      opacity={responder.available ? 1 : 0.4}
    >
      <Popup>
        <strong>{responder.name}</strong>
        <p>Role: {responder.role}</p>
        <p>
          Availability:{" "}
          {responder.available ? "Available" : "Unavailable"}
        </p>
      </Popup>
    </Marker>
  ))}


        {/* Risk-zone polygons */}
        
{/* Risk-zone polygons */}
{data?.zones && (
  <GeoJSON
    data={data.zones}
    style={(feature) => {
      const riskLevel = feature?.properties?.riskLevel;

      return {
        color: riskLevel === "HIGH" ? "#dc2626" : "#eab308",
        fillColor: riskLevel === "HIGH" ? "#ef4444" : "#facc15",
        fillOpacity: 0.25,
        weight: 2,
      };
    }}
    onEachFeature={(feature, layer) => {
      const name = feature.properties?.name ?? "Unnamed zone";
      const riskLevel =
        feature.properties?.riskLevel ?? "Unknown";

      layer.bindPopup(
        `<strong>${name}</strong><p>Risk: ${riskLevel}</p>`
      );
    }}
  />
)}


        {/* Resort markers */}
        {data?.resorts?.map((resort) => (
          <Marker
            key={`resort-${resort.id}`}
            position={[
              resort.location.lat,
              resort.location.lng,
            ]}
          >
            <Popup>
              <strong>{resort.name}</strong>
              <p>
                Fire equipment:{" "}
                {resort.fireEquipment || "Not available"}
              </p>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
       <IncidentDetails incident={selectedIncident} />
    </div>
  );
}

export default IncidentMap;
