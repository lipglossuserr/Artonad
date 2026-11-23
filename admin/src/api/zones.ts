
const API_BASE_URL = "http://localhost:8080/api/v1";

export async function getZones() {
  const token = localStorage.getItem("token");

  const response = await fetch(`${API_BASE_URL}/zones`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch zones: ${response.status}`);
  }

  return response.json();
}
