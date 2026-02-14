"use client";

import { useEffect, useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";

export default function BookService() {
  const [services, setServices] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  useEffect(() => {
    axios
      .get("http://localhost:5000/api/services")
      .then((res) => setServices(res.data))
      .catch((err) => {
        console.error("Failed to load services:", err);
        alert("Could not load services. Please try again.");
      });
  }, []);

  const handleBook = async (service: any) => {
    setLoading(true);
    try {
      const user = JSON.parse(localStorage.getItem("amexan_user") || "{}");
      if (!user._id) {
        alert("You must be logged in.");
        router.push("/login");
        return;
      }

      const res = await axios.post(
        "http://localhost:5000/api/appointments/create",
        {
          patientId: user._id,
          doctorId: service.doctorId?._id,   // 👈 critical fix
          serviceId: service._id,
          date: new Date().toISOString().split("T")[0],
          startTime: "10:00",
        }
      );

      router.push(`/dashboard/patient/payment/${res.data._id}`);
    } catch (err: any) {
      console.error("Booking error:", err);
      alert(err.response?.data?.error || "Booking failed. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-6">
      <h2 className="text-xl font-bold mb-6">Available Services</h2>

      {services.map((service) => (
        <div key={service._id} className="border p-4 mb-4 rounded">
          <h3 className="font-bold text-lg">{service.title}</h3>
          <p>{service.description}</p>
          <p>Doctor: Dr. {service.doctorId?.name || "Unknown"}</p>
          <p>Duration: {service.durationMinutes} mins</p>
          <p className="font-bold">KES 1</p>

          <button
            onClick={() => handleBook(service)}
            disabled={loading}
            className="bg-green-600 text-white px-4 py-2 mt-3 rounded disabled:bg-gray-400"
          >
            {loading ? "Processing..." : "Book & Pay"}
          </button>
        </div>
      ))}
    </div>
  );
}