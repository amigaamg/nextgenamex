"use client";

import { useEffect, useState } from "react";
import axios from "axios";

export default function DoctorServices() {
  const [services, setServices] = useState<any[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [duration, setDuration] = useState(30);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const stored = localStorage.getItem("amexan_user");
    if (stored) {
      setUser(JSON.parse(stored));
    }
  }, []);

  useEffect(() => {
    if (user?._id) {
      fetchServices();
    }
  }, [user]);

  const fetchServices = async () => {
    try {
      const res = await axios.get(
        `http://localhost:5000/api/services/doctor/${user._id}`
      );
      setServices(res.data);
    } catch (err) {
      console.error("FETCH ERROR:", err);
    }
  };

  const handleCreate = async () => {
    try {
      if (!user?._id) return alert("User not loaded");

      const res = await axios.post(
        "http://localhost:5000/api/services/create",
        {
          doctorId: user._id,
          title,
          description,
          durationMinutes: duration,
        }
      );

      console.log("CREATED:", res.data);

      setTitle("");
      setDescription("");
      fetchServices();
    } catch (err) {
      console.error("CREATE ERROR:", err);
      alert("Create failed. Check backend console.");
    }
  };

  const toggleService = async (id: string) => {
    await axios.put(
      `http://localhost:5000/api/services/toggle/${id}`
    );
    fetchServices();
  };

  if (!user) return <div className="p-6">Loading...</div>;

  return (
    <div className="p-6">
      <h2 className="text-xl font-bold mb-4">
        My Services (KES 1)
      </h2>

      <div className="mb-6 border p-4 rounded">
        <input
          placeholder="Service Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="border p-2 w-full mb-3"
        />

        <textarea
          placeholder="Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="border p-2 w-full mb-3"
        />

        <input
          type="number"
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
          className="border p-2 w-full mb-3"
        />

        <button
          onClick={handleCreate}
          className="bg-blue-600 text-white px-4 py-2 rounded"
        >
          Create Service
        </button>
      </div>

      {services.map((service) => (
        <div key={service._id} className="border p-4 mb-3 rounded">
          <h3 className="font-bold">{service.title}</h3>
          <p>{service.description}</p>
          <p>Duration: {service.durationMinutes} mins</p>
          <p>Status: {service.isActive ? "Active" : "Disabled"}</p>

          <button
            onClick={() => toggleService(service._id)}
            className="bg-gray-800 text-white px-3 py-1 mt-2 rounded"
          >
            Toggle
          </button>
        </div>
      ))}
    </div>
  );
}
