import { NextRequest, NextResponse } from "next/server";

/**
 * PAYHERO CALLBACK HANDLER
 * Receives payment confirmation from PayHero after STK push
 */
export async function POST(req: NextRequest) {
  try {
    const data = await req.json();

    console.log("🔔 PAYHERO CALLBACK RECEIVED:", data);

    /**
     * Expected data contains payment status.
     * Example fields PayHero may send:
     * - status
     * - external_reference
     * - amount
     * - phone_number
     * - transaction_id
     */

    const status = data.status;
    const reference = data.external_reference;

    if (status === "success") {
      console.log(`✅ PAYMENT SUCCESS for order: ${reference}`);

      /**
       * TODO — IMPORTANT:
       * Update your database here:
       * - mark appointment as PAID
       * - unlock booking
       * - notify patient/doctor
       */

    } else {
      console.log(`❌ PAYMENT FAILED for order: ${reference}`);
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error("❌ CALLBACK ERROR:", error);
    return NextResponse.json(
      { message: "Callback processing failed" },
      { status: 500 }
    );
  }
}
