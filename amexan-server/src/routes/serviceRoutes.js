const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");

// Prevent model overwrite crash
const Service =
  mongoose.models.Service ||
  mongoose.model(
    "Service",
    new mongoose.Schema(
      {
        doctorId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },
        title: { type: String, required: true },
        description: String,
        durationMinutes: Number,
        price: { type: Number, default: 1 },
        isActive: { type: Boolean, default: true },
      },
      { timestamps: true }
    )
  );

// CREATE SERVICE
router.post("/create", async (req, res) => {
  try {
    console.log("CREATE HIT");

    const { doctorId, title, description, durationMinutes } = req.body;

    if (!doctorId || !title) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const service = await Service.create({
      doctorId,
      title,
      description,
      durationMinutes,
    });

    res.status(201).json(service);
  } catch (err) {
    console.error("CREATE ERROR:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET ALL
router.get("/", async (req, res) => {
  const services = await Service.find({ isActive: true })
    .populate("doctorId", "name");
  res.json(services);
});

// GET DOCTOR SERVICES
router.get("/doctor/:doctorId", async (req, res) => {
  const services = await Service.find({
    doctorId: req.params.doctorId,
  });
  res.json(services);
});

// TOGGLE
router.put("/toggle/:id", async (req, res) => {
  const service = await Service.findById(req.params.id);
  service.isActive = !service.isActive;
  await service.save();
  res.json(service);
});

module.exports = router;
