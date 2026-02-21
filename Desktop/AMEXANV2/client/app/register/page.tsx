"use client";

import { useState } from "react";
import { auth, db } from "@/lib/firebase";
import { createUserWithEmailAndPassword } from "firebase/auth";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { useRouter } from "next/navigation";

export default function RegisterPage() {
  const router = useRouter();

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState("patient");

  const handleRegister = async () => {
    try {
      // 🔐 Create Auth user
      const res = await createUserWithEmailAndPassword(
        auth,
        email,
        password
      );

      const user = res.user;

      // 🧠 Save user profile in Firestore
      await setDoc(doc(db, "users", user.uid), {
        name,
        email,
        role,
        createdAt: serverTimestamp(),
        smartcardId: "AMX-" + Math.floor(100000 + Math.random() * 900000)
      });

      // 🚀 Redirect by role
      if (role === "doctor") router.push("/dashboard/doctor");
      else router.push("/dashboard/patient");

    } catch (err) {
      alert("Registration failed");
    }
  };

  return (
    <div className="flex h-screen items-center justify-center">
      <div className="bg-white p-8 rounded shadow w-96">

        <h1 className="text-2xl mb-4 font-bold">
          Register — AMEXAN
        </h1>

        <input
          className="border p-2 w-full mb-2"
          placeholder="Full Name"
          onChange={(e) => setName(e.target.value)}
        />

        <input
          className="border p-2 w-full mb-2"
          placeholder="Email"
          onChange={(e) => setEmail(e.target.value)}
        />

        <input
          type="password"
          className="border p-2 w-full mb-2"
          placeholder="Password"
          onChange={(e) => setPassword(e.target.value)}
        />

        {/* ROLE SELECT */}
        <select
          className="border p-2 w-full mb-4"
          value={role}
          onChange={(e) => setRole(e.target.value)}
        >
          <option value="patient">Patient</option>
          <option value="doctor">Doctor</option>
        </select>

        <button
          onClick={handleRegister}
          className="bg-black text-white w-full py-2"
        >
          Create Account
        </button>

      </div>
    </div>
  );
}