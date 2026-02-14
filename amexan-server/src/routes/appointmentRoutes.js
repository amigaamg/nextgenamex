const express = require("express");
const router = express.Router();
const crypto = require("crypto");
const Appointment = require("../../models/Appointment");  // ✅ fixed path
const Service = require("../../models/Service");          // ✅ fixed path

// CREATE appointment (auto‑fill required fields)
router.post("/create", async (req, res) => {
  try {
    let { patientId, doctorId, serviceId, date, startTime, durationMinutes, endTime, price } = req.body;

    if (!patientId || !doctorId || !serviceId || !date || !startTime) {
      return res.status(400).json({ error: "Missing required fields: patientId, doctorId, serviceId, date, startTime" });
    }

    const service = await Service.findById(serviceId);
    if (!service) return res.status(404).json({ error: "Service not found" });

    durationMinutes = durationMinutes || service.durationMinutes;
    if (!durationMinutes) return res.status(400).json({ error: "Duration missing" });

    price = price || service.price || 1;

    if (!endTime && startTime && durationMinutes) {
      const [hours, minutes] = startTime.split(':').map(Number);
      const startDate = new Date(date);
      startDate.setHours(hours, minutes, 0);
      const endDate = new Date(startDate.getTime() + durationMinutes * 60000);
      endTime = endDate.toTimeString().slice(0, 5);
    }

    const roomId = crypto.randomBytes(16).toString('hex');

    const appointment = new Appointment({
      patientId,
      doctorId,
      serviceId,
      date,
      startTime,
      endTime,
      durationMinutes,
      price,
      roomId,
      status: "pending",
      paymentStatus: "unpaid",
    });

    await appointment.save();
    res.status(201).json(appointment);
  } catch (err) {
    console.error("❌ Create appointment error:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET doctor appointments
router.get("/doctor/:doctorId", async (req, res) => {
  try {
    const appointments = await Appointment.find({ doctorId: req.params.doctorId })
      .populate("patientId", "name email")
      .populate("serviceId", "title durationMinutes")
      .sort({ createdAt: -1 });
    res.json(appointments);
  } catch (err) {
    console.error("Fetch doctor appointments error:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET patient appointments
router.get("/patient/:patientId", async (req, res) => {
  try {
    const appointments = await Appointment.find({ patientId: req.params.patientId })
      .populate("doctorId", "name")
      .populate("serviceId", "title")
      .sort({ createdAt: -1 });
    res.json(appointments);
  } catch (err) {
    console.error("Fetch patient appointments error:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET single appointment by ID (for consultation)
router.get("/:id", async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id)
      .populate("patientId", "name email")
      .populate("doctorId", "name")
      .populate("serviceId", "title");
    if (!appointment) return res.status(404).json({ error: "Appointment not found" });
    res.json(appointment);
  } catch (err) {
    console.error("Fetch appointment error:", err);
    res.status(500).json({ error: err.message });
  }
});

// PAY (confirm) – used after successful payment
router.put("/pay/:id", async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ error: "Appointment not found" });
    appointment.status = "confirmed";
    appointment.paymentStatus = "paid";
    await appointment.save();
    res.json({ message: "Paid and confirmed", appointment });
  } catch (err) {
    console.error("Pay error:", err);
    res.status(500).json({ error: err.message });
  }
});

// Cancel
router.put("/cancel/:id", async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ error: "Appointment not found" });
    appointment.status = "cancelled";
    await appointment.save();
    res.json({ message: "Appointment cancelled", appointment });
  } catch (err) {
    console.error("Cancel error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;