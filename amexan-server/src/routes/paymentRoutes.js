const express = require("express");
const router = express.Router();
const axios = require("axios");
const Appointment = require("../../models/Appointment");

// Load from .env
const PAYHERO_AUTH = process.env.PAYHERO_AUTH;
const PAYHERO_CHANNEL_ID = process.env.PAYHERO_CHANNEL_ID;
const PAYHERO_ENDPOINT = "https://backend.payhero.co.ke/api/v2/payments";
const PAYHERO_CALLBACK_URL = process.env.PAYHERO_CALLBACK_URL;

// ---------- INITIATE PAYMENT ----------
router.post("/initiate", async (req, res) => {
  try {
    const { appointmentId, phone, email } = req.body;

    if (!appointmentId || !phone || !email) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const appointment = await Appointment.findById(appointmentId);
    if (!appointment) {
      return res.status(404).json({ error: "Appointment not found" });
    }

    const formattedPhone = phone.replace(/\D/g, "");
    const phoneNumber = formattedPhone.startsWith("254")
      ? formattedPhone
      : `254${formattedPhone.slice(-9)}`;

    const externalReference = `APPT_${appointmentId}_${Date.now()}`;

    const payload = {
      amount: appointment.price || 1,
      phone_number: phoneNumber,
      channel_id: Number(PAYHERO_CHANNEL_ID),
      provider: "m-pesa",
      external_reference: externalReference,
      callback_url: PAYHERO_CALLBACK_URL,
      customer_name: email.split("@")[0] || "Patient",
    };

    console.log("📤 PayHero payload:", payload);

    const payheroRes = await axios.post(PAYHERO_ENDPOINT, payload, {
      headers: {
        Authorization: PAYHERO_AUTH,
        "Content-Type": "application/json",
      },
      timeout: 15000,
    });

    console.log("📥 PayHero response:", payheroRes.data);

    // Save reference so we can match the callback later
    appointment.paymentReference = externalReference;
    await appointment.save();

    res.json({ success: true, data: payheroRes.data });
  } catch (err) {
    console.error("❌ Payment initiation error:", err.message);
    if (err.response) {
      return res.status(err.response.status).json(err.response.data);
    } else if (err.code === "ECONNABORTED") {
      return res.status(504).json({ error: "Gateway timeout" });
    } else {
      return res.status(500).json({ error: "Payment gateway error" });
    }
  }
});

// ---------- PAYMENT CALLBACK (PayHero POSTs here) ----------
router.post("/callback", async (req, res) => {
  try {
    // Log the entire incoming body for debugging
    console.log("📞 Callback received – raw body:", JSON.stringify(req.body, null, 2));

    const body = req.body;

    // Try to extract the reference from possible field names
    const reference =
      body.external_reference ||
      body.reference ||
      body.Reference ||
      body.order_id ||
      body.transaction_reference;

    // Try to extract the status from possible field names
    const status =
      body.status ||
      body.Status ||
      body.transaction_status ||
      body.resultCode ||
      body.resultDesc;

    console.log("🔍 Extracted – reference:", reference, "status:", status);

    if (!reference) {
      console.error("❌ No reference found in callback body – cannot update appointment");
      // Still return 200 to acknowledge receipt
      return res.sendStatus(200);
    }

    // Find appointment by paymentReference
    const appointment = await Appointment.findOne({ paymentReference: reference });
    if (!appointment) {
      console.error("❌ Appointment not found for reference:", reference);
      return res.sendStatus(200); // 200 so PayHero doesn't retry
    }

    // Define success/failure keywords (adjust based on PayHero's actual values)
    const successKeywords = ["completed", "success", "paid", "SUCCESS", "COMPLETED", "0"];
    const failureKeywords = ["failed", "cancelled", "error", "FAILED", "CANCELLED", "1"];

    const statusLower = status ? status.toString().toLowerCase() : "";

    if (successKeywords.some(keyword => statusLower.includes(keyword))) {
      appointment.paymentStatus = "paid";
      appointment.status = "confirmed";
      console.log(`✅ Payment confirmed for appointment ${appointment._id}`);
    } else if (failureKeywords.some(keyword => statusLower.includes(keyword))) {
      appointment.paymentStatus = "failed";
      console.log(`❌ Payment failed for appointment ${appointment._id}`);
    } else {
      console.log(`⚠️ Unknown payment status "${status}" for appointment ${appointment._id} – no changes made`);
    }

    await appointment.save();
    res.sendStatus(200);
  } catch (err) {
    console.error("🔥 Callback error:", err);
    // Always return 200 so PayHero stops retrying
    res.sendStatus(200);
  }
});

// ---------- (OPTIONAL) MANUAL CONFIRM FOR DEVELOPMENT ----------
// Remove this before going live
router.post("/manual-confirm/:id", async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ error: "Not found" });
    appointment.paymentStatus = "paid";
    appointment.status = "confirmed";
    await appointment.save();
    res.json({ message: "Appointment confirmed manually (development only)" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;