
export interface Responder {
  id: number;
  name: string;
  role: "LIFEGUARD" | "FIREFIGHTER";
  available: boolean;
  location: {
    lat: number;
    lng: number;
  };
}

const API_BASE_URL = "http://localhost:8080/api/v1";

export async function getResponders(): Promise<Responder[]> {
  const token = localStorage.getItem("token");

  const response = await fetch(`${API_BASE_URL}/responders`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(
      `Failed to load responders: ${response.status}`
    );
  }

  return response.json();
}
