import IncidentMap from "../components/IncidentMap";
function Dashboard() {
  return (
    <div style={{ padding: "30px" }}>
      <h1>CoastGuard 360</h1>
      <h2>Emergency Operations Dashboard</h2>

      <p>Welcome, Admin!</p>

      <div
        style={{
          background: "white",
          padding: "20px",
          borderRadius: "10px",
          marginTop: "20px",
        }}
      >
        <h3>Live Emergency Map</h3>
        <IncidentMap />
      </div>

      <div
        style={{
          background: "white",
          padding: "20px",
          borderRadius: "10px",
          marginTop: "20px",
        }}
      >
        <h3>Recent Incidents</h3>
        <p>Incident information will appear here.</p>
      </div>
    </div>
  );
}

export default Dashboard;
