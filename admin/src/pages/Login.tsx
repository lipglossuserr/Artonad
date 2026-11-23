
import { useState } from "react";
import { login } from "../api/auth";
import { useNavigate } from "react-router-dom";

function Login() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const navigate = useNavigate();
  
async function handleLogin(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();

  try {
    const data = await login(username, password);

    if (data.role !== "ADMIN") {
      alert("Access denied. Admin account required.");
      return;
    }

    localStorage.setItem("token", data.token);
    localStorage.setItem("role", data.role);

    navigate("/dashboard");
  } catch (error) {
    console.error(error);
    alert("Login failed. Check your credentials or backend connection.");
  }
}

  return (
    <div style={{
      display: "flex",
      justifyContent: "center",
      alignItems: "center",
      minHeight: "100vh"
    }}>
      <form onSubmit={handleLogin} style={{
        background: "white",
        padding: "40px",
        borderRadius: "12px",
        width: "360px",
        boxShadow: "0 4px 15px rgba(0,0,0,0.1)"
      }}>
        <h1>CoastGuard 360</h1>
        <h2>Admin Login</h2>

        <label>Username</label>
        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
          style={{ width: "100%", padding: "10px", marginBottom: "16px" }}
        />

        <label>Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          style={{ width: "100%", padding: "10px", marginBottom: "20px" }}
        />

        <button type="submit" style={{
          width: "100%",
          padding: "12px",
          background: "#0f172a",
          color: "white",
          border: "none",
          borderRadius: "6px",
          cursor: "pointer"
        }}>
          Login
        </button>
      </form>
    </div>
  );
}

export default Login;
