import { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  console.log("PayHero Callback Received:", req.body);

  // TODO: Update appointment payment status in your DB
  // Example:
  // await Appointment.update({ status: "paid" }, { where: { id: req.body.external_reference } });

  res.status(200).send("OK");
}