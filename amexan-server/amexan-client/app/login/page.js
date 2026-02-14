"use client";

import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // Use environment variable with fallback to 127.0.0.1 (more reliable on Windows)
  const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:5000";

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const res = await axios.post(`${API_BASE}/api/auth/login`, {
        email,
        password,
      });

      // Save to localStorage
      localStorage.setItem("amexan_token", res.data.token);
      localStorage.setItem("amexan_user", JSON.stringify(res.data.user));

      // Redirect based on role
      const role = res.data.user.role;
      if (role === "doctor") {
        router.push("/dashboard/doctor");
      } else if (role === "patient") {
        router.push("/dashboard/patient");
      } else {
        router.push("/dashboard");
      }
    } catch (err) {
      console.error("Login error:", err);

      if (err.code === "ERR_NETWORK") {
        setError(
          "❌ Cannot reach backend. Make sure the server is running on http://127.0.0.1:5000"
        );
      } else if (err.response) {
        // Server responded with an error (4xx/5xx)
        setError(err.response.data?.error || "Login failed");
      } else if (err.request) {
        setError("No response from server. Check your network.");
      } else {
        setError(err.message);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 400, margin: "2rem auto", padding: "1rem" }}>
      <h1>Login</h1>
      {error && (
        <div style={{ color: "red", background: "#ffeeee", padding: "0.5rem", borderRadius: 4 }}>
          {error}
        </div>
      )}
      <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          disabled={loading}
          style={{ padding: 8 }}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          disabled={loading}
          style={{ padding: 8 }}
        />
        <button
          type="submit"
          disabled={loading}
          style={{
            padding: 10,
            backgroundColor: loading ? "#ccc" : "#0070f3",
            color: "white",
            border: "none",
            cursor: loading ? "not-allowed" : "pointer",
          }}
        >
          {loading ? "Logging in..." : "Login"}
        </button>
      </form>
    </div>
  );
}