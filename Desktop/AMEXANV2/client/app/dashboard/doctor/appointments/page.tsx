"use client";

import { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs, doc, setDoc } from "firebase/firestore";
import { useRouter } from "next/navigation";
import { v4 as uuidv4 } from "uuid";

export default function DoctorAppointments() {
  const [appointments, setAppointments] = useState<any[]>([]);
  const router = useRouter();

  useEffect(() => {
    const load = async () => {
      const doctor = auth.currentUser;
      if (!doctor) return;

      const q = query(collection(db, "appointments"), where("doctorId", "==", doctor.uid));
      const snap = await getDocs(q);
      setAppointments(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    };
    load();
  }, []);

  const startConsultation = async (appointment: any) => {
    const consultationId = uuidv4();
    const videoRoomId = uuidv4();

    await setDoc(doc(db, "consultations", consultationId), {
      appointmentId: appointment.id,
      doctorId: appointment.doctorId,
      patientId: appointment.patientId,
      videoRoomId,
      status: "active",
      chat: [],
      prescriptions: [],
    });

    router.push(`/dashboard/consultation/${consultationId}`);
  };

  return (
    <div className="p-10">
      <h1 className="text-3xl font-bold mb-6">My Appointments</h1>
      {appointments.map((a, i) => (
        <div key={i} className="border p-4 mb-2 flex justify-between items-center">
          <div>
            Patient ID: {a.patientId} <br />
            Status: {a.status}
          </div>
          <button
            className="bg-green-600 text-white px-4 py-2"
            onClick={() => startConsultation(a)}
          >
            Start Consultation
          </button>
        </div>
      ))}
    </div>
  );
}