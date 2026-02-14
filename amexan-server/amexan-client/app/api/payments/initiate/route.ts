import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const { phone, amount, orderId, customerName } = await req.json();

    if (!phone || !amount || !orderId) {
      return NextResponse.json(
        { message: "Missing required fields" },
        { status: 400 }
      );
    }

    const payload = {
      amount: Number(amount),
      phone_number: phone, // 2547XXXXXXXX
      channel_id: Number(process.env.PAYHERO_CHANNEL_ID),
      provider: "m-pesa",
      external_reference: orderId,
      callback_url: process.env.PAYHERO_CALLBACK_URL,
      customer_name: customerName || "Patient",
    };

    console.log("🚀 STK REQUEST PAYLOAD:", payload);

    const response = await fetch(
      process.env.PAYHERO_ENDPOINT!,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: process.env.PAYHERO_AUTH!,
        },
        body: JSON.stringify(payload),
      }
    );

    const data = await response.json();

    console.log("🔥 PAYHERO RESPONSE:", data);

    if (!response.ok) {
      return NextResponse.json(data, { status: response.status });
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error("❌ STK Push Error:", error);
    return NextResponse.json(
      { message: "Payment initiation failed" },
      { status: 500 }
    );
  }
}
