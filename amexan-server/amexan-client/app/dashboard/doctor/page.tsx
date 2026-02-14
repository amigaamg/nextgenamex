"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export default function DoctorDashboard() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const stored = localStorage.getItem("amexan_user");

    if (!stored) {
      router.push("/login");
      return;
    }

    const parsed = JSON.parse(stored);

    if (parsed.role !== "doctor") {
      router.push("/dashboard");
      return;
    }

    setUser(parsed);
  }, []);

  if (!user) return null;

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-2">
        Welcome Dr. {user.name}
      </h1>
      <p className="text-gray-500 mb-8">
        Manage your services, bookings, and patients
      </p>

      <div className="grid md:grid-cols-2 gap-6">

        {/* SERVICE CARD MANAGEMENT */}
        <div
          onClick={() => router.push("/dashboard/doctor/services")}
          className="border p-6 rounded-xl shadow hover:shadow-lg cursor-pointer transition"
        >
          <h2 className="text-xl font-semibold mb-2">
            🩺 Manage Service Cards
          </h2>
          <p className="text-gray-600">
            Create, edit, or disable consultation services (KES 1)
          </p>
        </div>

        {/* APPOINTMENTS */}
        <div
          onClick={() => router.push("/dashboard/doctor/appointments")}
          className="border p-6 rounded-xl shadow hover:shadow-lg cursor-pointer transition"
        >
          <h2 className="text-xl font-semibold mb-2">
            📅 View Appointments
          </h2>
          <p className="text-gray-600">
            See all patient bookings and join consultations
          </p>
        </div>

        {/* EARNINGS */}
        <div
          onClick={() => router.push("/dashboard/doctor/earnings")}
          className="border p-6 rounded-xl shadow hover:shadow-lg cursor-pointer transition"
        >
          <h2 className="text-xl font-semibold mb-2">
            💰 Earnings
          </h2>
          <p className="text-gray-600">
            Track payments and revenue
          </p>
        </div>

        {/* CHRONIC CARE */}
        <div
          onClick={() => router.push("/dashboard/doctor/patients")}
          className="border p-6 rounded-xl shadow hover:shadow-lg cursor-pointer transition"
        >
          <h2 className="text-xl font-semibold mb-2">
            ❤️ Chronic Care
          </h2>
          <p className="text-gray-600">
            Manage long-term follow-ups
          </p>
        </div>

      </div>
    </div>
  );
}
