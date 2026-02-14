"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import axios from "axios";

export default function PaymentPage() {
  const { id } = useParams();
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [testLoading, setTestLoading] = useState(false);

  const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000";

  const handlePay = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const res = await axios.post(`${API_BASE}/api/payments/initiate`, {
        appointmentId: id,
        phone,
        email,
      });
      console.log("Payment initiated:", res.data);
      alert("📲 STK Push sent. Check your phone.");
    } catch (err: any) {
      console.error("Payment error:", err);
      alert(err.response?.data?.error || "Payment initiation failed");
    } finally {
      setLoading(false);
    }
  };

  // 🔧 TEST BUTTON: manually confirm and go to consultation
  const handleManualConfirm = async () => {
    setTestLoading(true);
    try {
      await axios.post(`${API_BASE}/api/payments/manual-confirm/${id}`);
      router.push(`/consultation/${id}`); // redirect to consultation page
    } catch (err: any) {
      console.error("Manual confirm error:", err);
      alert("Failed to confirm manually");
    } finally {
      setTestLoading(false);
    }
  };

  return (
    <div className="p-6 max-w-md mx-auto">
      <h2 className="text-xl font-bold mb-4">Complete Payment</h2>
      <form onSubmit={handlePay} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Phone Number (M-Pesa)</label>
          <input
            type="tel"
            placeholder="e.g., 0712345678 or 254712345678"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            required
            className="w-full p-2 border rounded"
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Email</label>
          <input
            type="email"
            placeholder="your@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            className="w-full p-2 border rounded"
          />
        </div>
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-green-600 text-white py-2 rounded disabled:bg-gray-400"
        >
          {loading ? "Processing..." : "Pay Now (STK Push)"}
        </button>
      </form>

      {/* 🔧 TEST BUTTON – remove before going live */}
      <div className="mt-6 pt-4 border-t">
        <button
          onClick={handleManualConfirm}
          disabled={testLoading}
          className="w-full bg-blue-500 text-white py-2 rounded disabled:bg-gray-400"
        >
          {testLoading ? "Processing..." : "🔧 Proceed to Consultation (Test) – Skip Payment"}
        </button>
        <p className="text-xs text-gray-500 mt-2 text-center">
          For development only – marks appointment as paid and redirects to video call.
        </p>
      </div>
    </div>
  );
}