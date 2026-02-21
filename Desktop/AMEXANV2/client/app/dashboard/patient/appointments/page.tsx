"use client";

import { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import { useRouter } from "next/navigation";

export default function PatientAppointments() {
  const [appointments, setAppointments] = useState<any[]>([]);
  const router = useRouter();

  useEffect(() => {
    const load = async () => {
      const patient = auth.currentUser;
      if (!patient) return;

      const q = query(collection(db, "appointments"), where("patientId", "==", patient.uid));
      const snap = await getDocs(q);
      setAppointments(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    };
    load();
  }, []);

  const joinConsultation = async (appointment: any) => {
    // Find consultation linked to this appointment
    const q = query(collection(db, "consultations"), where("appointmentId", "==", appointment.id));
    const snap = await getDocs(q);
    if (snap.empty) return alert("Consultation not started yet by doctor.");

    const consultation = snap.docs[0].id;
    router.push(`/dashboard/consultation/${consultation}`);
  };

  return (
    <div className="p-10">
      <h1 className="text-3xl font-bold mb-6">My Appointments</h1>
      {appointments.map((a, i) => (
        <div key={i} className="border p-4 mb-2 flex justify-between items-center">
          <div>
            Doctor ID: {a.doctorId} <br />
            Status: {a.status}
          </div>
          <button
            className="bg-blue-600 text-white px-4 py-2"
            onClick={() => joinConsultation(a)}
          >
            Join Consultation
          </button>
        </div>
      ))}
    </div>
  );
}