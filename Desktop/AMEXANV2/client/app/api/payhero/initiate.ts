import { NextApiRequest, NextApiResponse } from "next";
import axios from "axios";

type RequestBody = {
  phone: string;
  amount: number;
  appointmentId: string;
  patientName: string;
  specialty?: string;
};

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ message: "Method not allowed" });
  }

  const { phone, amount, appointmentId, patientName, specialty }: RequestBody = req.body;

  if (!phone || !amount || !appointmentId || !patientName) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const response = await axios.post(
      "https://backend.payhero.co.ke/api/v2/payments",
      {
        amount,
        phone_number: phone.startsWith("07") ? "254" + phone.slice(1) : phone, // convert 07… to 254…
        channel_id: Number(process.env.PAYHERO_CHANNEL_ID),
        provider: "m-pesa",
        external_reference: appointmentId,
        customer_name: patientName,
        description: `AMEXAN: ${specialty || "Consultation"}`,
        callback_url: process.env.PAYHERO_CALLBACK_URL,
      },
      {
        headers: {
          Authorization: process.env.PAYHERO_AUTH!,
          "Content-Type": "application/json",
        },
      }
    );

    return res.status(200).json({ success: true, data: response.data });
  } catch (error: any) {
    console.error("STK Push Error:", error.response?.data || error.message);
    return res.status(500).json({
      success: false,
      message: error.response?.data?.message || "STK push failed",
    });
  }
}