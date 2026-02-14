"use client";

import { useEffect, useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";

export default function PatientDashboard() {
  const [appointments, setAppointments] = useState<any[]>([]);
  const router = useRouter();

  const user =
    typeof window !== "undefined"
      ? JSON.parse(localStorage.getItem("amexan_user") || "{}")
      : {};

  useEffect(() => {
    if (!user._id) return;

    axios
      .get(`http://localhost:5000/api/appointments/patient/${user._id}`)
      .then(res => setAppointments(res.data));
  }, []);

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6">
        Welcome {user.name}
      </h1>

      <div className="grid md:grid-cols-2 gap-6">

        {/* BOOK NEW */}
        <div
          onClick={() => router.push("/dashboard/patient/book")}
          className="border p-6 rounded cursor-pointer hover:shadow"
        >
          <h2 className="text-lg font-semibold">🩺 Book Consultation</h2>
          <p className="text-gray-600">Browse available services</p>
        </div>

        {/* HISTORY */}
        <div className="border p-6 rounded">
          <h2 className="text-lg font-semibold mb-4">
            📅 Booking History
          </h2>

          {appointments.length === 0 && (
            <p className="text-gray-500">No bookings yet</p>
          )}

          {appointments.map(appt => (
            <div key={appt._id} className="mb-3 border-b pb-2">
              <p><strong>{appt.serviceId?.title}</strong></p>
              <p>Doctor: Dr. {appt.doctorId?.name}</p>
              <p>Status: {appt.status}</p>
              <p>Date: {appt.date}</p>
            </div>
          ))}
        </div>

      </div>
    </div>
  );
}
