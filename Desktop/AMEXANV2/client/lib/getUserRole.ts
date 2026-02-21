import { auth, db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";

export const getUserRole = async () => {
  const user = auth.currentUser;

  if (!user) return null;

  const docRef = doc(db, "users", user.uid);
  const snap = await getDoc(docRef);

  if (!snap.exists()) return null;

  return snap.data().role;
};