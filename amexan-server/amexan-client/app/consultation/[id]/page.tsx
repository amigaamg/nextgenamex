"use client";

import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import axios from "axios";
import io from "socket.io-client";

export default function ConsultationPage() {
  const { id } = useParams();
  const [appointment, setAppointment] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [messages, setMessages] = useState<any[]>([]);
  const [messageInput, setMessageInput] = useState("");

  const localVideo = useRef<HTMLVideoElement>(null);
  const remoteVideo = useRef<HTMLVideoElement>(null);
  const peerConnection = useRef<RTCPeerConnection | null>(null);
  const socketRef = useRef<any>(null);
  const localStreamRef = useRef<MediaStream | null>(null);

  const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000";

  // Fetch appointment details to get roomId
  useEffect(() => {
    const fetchAppointment = async () => {
      try {
        const res = await axios.get(`${API_BASE}/api/appointments/${id}`);
        setAppointment(res.data);
      } catch (err) {
        console.error("Failed to load appointment", err);
        alert("Could not load appointment details");
      } finally {
        setLoading(false);
      }
    };
    fetchAppointment();
  }, [id, API_BASE]);

  // Initialize socket and WebRTC once we have roomId
  useEffect(() => {
    if (!appointment?.roomId) return;

    const roomId = appointment.roomId;
    console.log("Using roomId:", roomId);

    // 1. Socket connection
    const socket = io(API_BASE);
    socketRef.current = socket;

    socket.on("connect", () => {
      console.log("✅ Socket connected", socket.id);
      socket.emit("join_room", roomId);
    });

    // 2. Camera + PeerConnection
    (async () => {
      try {
        if (!navigator.mediaDevices?.getUserMedia) {
          alert("❌ Camera not available. Use HTTPS or localhost.");
          return;
        }

        const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
        localStreamRef.current = stream;
        if (localVideo.current) localVideo.current.srcObject = stream;
        console.log("✅ Local camera ready");

        const pc = new RTCPeerConnection({
          iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
        });
        peerConnection.current = pc;

        stream.getTracks().forEach((track) => pc.addTrack(track, stream));

        pc.onicecandidate = (e) => {
          if (e.candidate) {
            socket.emit("ice_candidate", { room: roomId, candidate: e.candidate });
          }
        };

        pc.ontrack = (e) => {
          console.log("✅ Remote track received!");
          if (remoteVideo.current) remoteVideo.current.srcObject = e.streams[0];
        };

        // Simple offer logic: one side creates offer, the other answers.
        // Here we just let the first peer create an offer after a short delay.
        setTimeout(async () => {
          if (!peerConnection.current) return;
          console.log("📞 Creating offer...");
          const offer = await peerConnection.current.createOffer();
          await peerConnection.current.setLocalDescription(offer);
          socket.emit("offer", { room: roomId, offer });
        }, 1000);
      } catch (err) {
        console.error("❌ Camera/WebRTC error:", err);
        alert("Could not access camera: " + err);
      }
    })();

    // 3. Signaling handlers
    socket.on("offer", async (offer: RTCSessionDescriptionInit) => {
      console.log("📞 Received offer");
      if (!peerConnection.current) return;
      try {
        await peerConnection.current.setRemoteDescription(new RTCSessionDescription(offer));
        const answer = await peerConnection.current.createAnswer();
        await peerConnection.current.setLocalDescription(answer);
        socket.emit("answer", { room: roomId, answer });
      } catch (err) {
        console.error("❌ Offer error:", err);
      }
    });

    socket.on("answer", async (answer: RTCSessionDescriptionInit) => {
      console.log("📞 Received answer");
      if (!peerConnection.current) return;
      try {
        await peerConnection.current.setRemoteDescription(new RTCSessionDescription(answer));
      } catch (err) {
        console.error("❌ Answer error:", err);
      }
    });

    socket.on("ice_candidate", async (candidate: RTCIceCandidateInit) => {
      console.log("🧊 Received ICE candidate");
      if (!peerConnection.current) return;
      try {
        await peerConnection.current.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (err) {
        console.error("❌ ICE error:", err);
      }
    });

    socket.on("receive_message", (data: { message: string }) => {
      setMessages((prev) => [...prev, { text: data.message, from: "remote" }]);
    });

    return () => {
      socket.disconnect();
      if (localStreamRef.current) {
        localStreamRef.current.getTracks().forEach((t) => t.stop());
      }
      if (peerConnection.current) peerConnection.current.close();
    };
  }, [appointment, API_BASE]);

  const sendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!messageInput.trim() || !socketRef.current || !appointment?.roomId) return;
    const msg = messageInput;
    socketRef.current.emit("send_message", { room: appointment.roomId, message: msg });
    setMessages((prev) => [...prev, { text: msg, from: "local" }]);
    setMessageInput("");
  };

  if (loading) return <div className="p-6">Loading consultation...</div>;
  if (!appointment) return <div className="p-6">Appointment not found</div>;

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-2">Consultation Room</h1>
      <p className="mb-4">
        <strong>Room ID:</strong> {appointment.roomId} <br />
        <strong>Doctor:</strong> Dr. {appointment.doctorId?.name || "Unknown"} <br />
        <strong>Patient:</strong> {appointment.patientId?.name || "You"}
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div>
          <h3 className="font-semibold mb-1">You</h3>
          <video
            ref={localVideo}
            autoPlay
            playsInline
            muted
            className="w-full bg-black rounded"
            style={{ height: 240 }}
          />
        </div>
        <div>
          <h3 className="font-semibold mb-1">Remote</h3>
          <video
            ref={remoteVideo}
            autoPlay
            playsInline
            className="w-full bg-black rounded"
            style={{ height: 240 }}
          />
        </div>
      </div>

      {/* Chat */}
      <div className="border rounded p-4">
        <h2 className="font-semibold mb-2">💬 Chat</h2>
        <div className="h-48 overflow-y-auto border p-2 mb-2 bg-gray-50">
          {messages.map((msg, i) => (
            <div key={i} className={`mb-1 ${msg.from === "local" ? "text-right" : "text-left"}`}>
              <span
                className={`inline-block px-3 py-1 rounded ${
                  msg.from === "local" ? "bg-blue-500 text-white" : "bg-gray-300"
                }`}
              >
                {msg.text}
              </span>
            </div>
          ))}
        </div>
        <form onSubmit={sendMessage} className="flex gap-2">
          <input
            type="text"
            value={messageInput}
            onChange={(e) => setMessageInput(e.target.value)}
            className="flex-1 border p-2 rounded"
            placeholder="Type a message..."
          />
          <button type="submit" className="bg-blue-500 text-white px-4 py-2 rounded">
            Send
          </button>
        </form>
      </div>
    </div>
  );
}