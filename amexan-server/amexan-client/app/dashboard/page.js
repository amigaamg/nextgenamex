"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function DashboardRedirect() {
  const router = useRouter();

  useEffect(() => {
    const stored = localStorage.getItem("amexan_user");

    if (!stored) {
      router.push("/login");
      return;
    }

    const user = JSON.parse(stored);

    if (user.role === "doctor") {
      router.push("/dashboard/doctor");
    } else if (user.role === "patient") {
      router.push("/dashboard/patient");
    } else {
      router.push("/login");
    }
  }, []);

  return null;
}
