import { auth, db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";

export const getUserRole = async () => {
  const user = auth.currentUser;

  if (!user) return null;

  const docRef = doc(db, "users", user.uid);
  const docSnap = await getDoc(docRef);

  if (!docSnap.exists()) return null;

  return docSnap.data().role;
};