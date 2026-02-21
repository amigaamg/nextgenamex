import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/firebase-admin'; // Use admin SDK on server
import { collection, query, where, getDocs, updateDoc, doc, addDoc, serverTimestamp } from 'firebase/firestore';

// POST /api/payhero-callback — receives M-Pesa STK push result from PayHero
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    // PayHero sends: { status, reference, amount, phone, external_reference, ... }
    const {
      status,             // "Success" | "Failed"
      reference,          // PayHero reference / M-Pesa receipt
      amount,
      phone_number,
      external_reference, // This is our appointmentId
      result_description,
    } = body;

    if (!external_reference) {
      return NextResponse.json({ error: 'No reference provided' }, { status: 400 });
    }

    const appointmentRef = doc(db as any, 'appointments', external_reference);

    if (status === 'Success') {
      // Mark appointment as paid and generate receipt
      await updateDoc(appointmentRef, {
        paymentStatus: 'paid',
        paymentRef: reference,
        paymentReceipt: reference,
        paymentPhone: phone_number,
        paymentAmount: amount,
        paidAt: serverTimestamp(),
        status: 'booked',          // Confirmed once paid
      });

      // Create receipt document
      await addDoc(collection(db as any, 'receipts'), {
        appointmentId: external_reference,
        reference,
        amount,
        phone: phone_number,
        status: 'paid',
        createdAt: serverTimestamp(),
      });

      // Create notification for patient
      // Fetch appointment to get patientId
      // (in production, use admin SDK for atomic ops)

      return NextResponse.json({ success: true, message: 'Payment confirmed' });
    } else {
      // Payment failed — allow retry
      await updateDoc(appointmentRef, {
        paymentStatus: 'failed',
        paymentFailReason: result_description || 'Payment declined',
        updatedAt: serverTimestamp(),
      });

      return NextResponse.json({ success: false, message: 'Payment failed' });
    }
  } catch (error: any) {
    console.error('PayHero callback error:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}