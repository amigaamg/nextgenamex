import { NextRequest, NextResponse } from "next/server";
import axios from "axios";

export async function POST(req: NextRequest) {
  const { phone, amount, appointmentId } = await req.json();

  try {
    const response = await axios.post(
      process.env.PAYHERO_ENDPOINT!,
      {
        channel_id: process.env.PAYHERO_CHANNEL_ID,
        phone_number: phone,
        amount,
        external_reference: appointmentId,
        callback_url: process.env.PAYHERO_CALLBACK_URL,
      },
      {
        headers: {
          Authorization: process.env.PAYHERO_AUTH!,
          "Content-Type": "application/json",
        },
      }
    );

    return NextResponse.json(response.data);
  } catch (error: any) {
    console.error(error.response?.data || error.message);
    return NextResponse.json(
      { error: "STK push failed" },
      { status: 500 }
    );
  }
}