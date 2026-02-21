"use client";

import { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import {
  collection,
  getDocs,
  addDoc
} from "firebase/firestore";

export default function BookAppointment() {
  const [services, setServices] = useState<any[]>([]);

  useEffect(() => {
    const loadServices = async () => {
      const snap = await getDocs(collection(db, "services"));
      setServices(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    };

    loadServices();
  }, []);

  const book = async (service: any) => {
    const patient = auth.currentUser;

    if (!patient) return;

    await addDoc(collection(db, "appointments"), {
      patientId: patient.uid,
      doctorId: service.doctorId,
      serviceId: service.id,
      status: "booked",
      date: new Date()
    });

    alert("Appointment booked 🚀");
  };

  return (
    <div className="p-10">

      <h1 className="text-3xl font-bold mb-6">
        Available Doctors
      </h1>

      <div className="grid grid-cols-3 gap-4">

        {services.map(service => (
          <div
            key={service.id}
            className="border p-4 rounded shadow"
          >
            <h2 className="font-bold text-xl">
              {service.specialty}
            </h2>

            <p>Clinic: {service.clinic}</p>
            <p>Doctor: {service.doctorName}</p>
            <p>Fee: {service.price}</p>

            <button
              onClick={() => book(service)}
              className="bg-black text-white px-3 py-1 mt-2"
            >
              Book
            </button>
          </div>
        ))}

      </div>
    </div>
  );
}