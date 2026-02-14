"use client";
import { useRouter } from "next/navigation";

export default function Home() {
  const router = useRouter();
  return (
    <div style={{ padding: 20 }}>
      <h1>Welcome to AMEXAN Telemedicine</h1>
      <button onClick={() => router.push("/register")}>Register</button>
      <button onClick={() => router.push("/login")}>Login</button>
    </div>
  );
}
