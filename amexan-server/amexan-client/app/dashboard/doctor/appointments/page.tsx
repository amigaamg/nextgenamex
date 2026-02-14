"use client";

import { useEffect, useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";

export default function DoctorAppointments() {
  const [appointments, setAppointments] = useState<any[]>([]);
  const router = useRouter();

  const user = JSON.parse(localStorage.getItem("amexan_user") || "{}");

  useEffect(() => {
    axios
      .get(
        `http://localhost:5000/api/appointments/doctor/${user._id}`
      )
      .then((res) => setAppointments(res.data));
  }, []);

  return (
    <div className="p-6">
      <h2 className="text-xl font-bold mb-6">My Appointments</h2>

      {appointments.map((appt) => (
        <div key={appt._id} className="border p-4 mb-4 rounded">
          <p>Status: {appt.status}</p>
          <p>Date: {appt.date}</p>
          <p>Time: {appt.startTime}</p>
          <p>Price: {appt.price}</p>

          {appt.status === "confirmed" && (
            <button
              onClick={() =>
                router.push(`/consultation/${appt._id}`)
              }
              className="bg-green-600 text-white px-4 py-2 mt-2 rounded"
            >
              Join Consultation
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
