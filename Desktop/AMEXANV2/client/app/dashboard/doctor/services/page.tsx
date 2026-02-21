"use client";

import { useState } from "react";
import { auth, db } from "@/lib/firebase";
import { collection, addDoc } from "firebase/firestore";

export default function DoctorServices() {
  const [specialty, setSpecialty] = useState("");
  const [clinic, setClinic] = useState("");
  const [price, setPrice] = useState("");
  const [description, setDescription] = useState("");

  const createService = async () => {
    const doctor = auth.currentUser;
    if (!doctor) return alert("Not logged in");

    if (!specialty || !clinic || !price || !description)
      return alert("Fill all fields");

    await addDoc(collection(db, "services"), {
      doctorId: doctor.uid,
      doctorName: doctor.email,
      specialty,
      clinic,
      price,
      description,
      createdAt: new Date(),
    });

    alert("Service created ✅");
    setSpecialty(""); setClinic(""); setPrice(""); setDescription("");
  };

  return (
    <div className="p-10">
      <h1 className="text-2xl font-bold mb-4">Create Service</h1>
      <input placeholder="Specialty" value={specialty} onChange={e => setSpecialty(e.target.value)} className="border p-2 mb-2 w-full"/>
      <input placeholder="Clinic" value={clinic} onChange={e => setClinic(e.target.value)} className="border p-2 mb-2 w-full"/>
      <input placeholder="Price" value={price} onChange={e => setPrice(e.target.value)} className="border p-2 mb-2 w-full"/>
      <textarea placeholder="Description" value={description} onChange={e => setDescription(e.target.value)} className="border p-2 mb-2 w-full"/>
      <button onClick={createService} className="bg-black text-white px-4 py-2">Publish Service</button>
    </div>
  );
}