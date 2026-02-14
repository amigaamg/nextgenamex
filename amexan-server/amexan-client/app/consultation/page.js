"use client";

import { useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import io from "socket.io-client";

export default function Consultation() {
  const searchParams = useSearchParams();
  // ⚠️ IMPORTANT: Use the EXACT SAME room on both devices!
  const roomId = searchParams.get("room") || "same-room-please";

  const localVideo = useRef(null);
  const remoteVideo = useRef(null);
  const peerConnection = useRef(null);
  const socketRef = useRef(null);
  const localStreamRef = useRef(null);
  const [messages, setMessages] = useState([]);
  const [messageInput, setMessageInput] = useState("");

  useEffect(() => {
    // 1. Socket connection
    const socket = io(process.env.NEXT_PUBLIC_SOCKET_URL || "http://localhost:5000");
    socketRef.current = socket;

    socket.on("connect", () => {
      console.log("✅ Socket connected", socket.id);
      socket.emit("join_room", roomId);
    });

    // 2. Camera + PeerConnection – starts automatically
    (async () => {
      try {
        if (!navigator.mediaDevices?.getUserMedia) {
          alert("❌ Camera not available. Use Firefox / HTTPS / localhost.");
          return;
        }

        // Get local stream
        const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
        localStreamRef.current = stream;
        if (localVideo.current) localVideo.current.srcObject = stream;
        console.log("✅ Local camera ready");

        // Create PeerConnection
        const pc = new RTCPeerConnection({
          iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
        });
        peerConnection.current = pc;

        // Add tracks
        stream.getTracks().forEach((track) => pc.addTrack(track, stream));

        // ICE candidates
        pc.onicecandidate = (e) => {
          if (e.candidate) {
            socket.emit("ice_candidate", { room: roomId, candidate: e.candidate });
          }
        };

        // Remote stream
        pc.ontrack = (e) => {
          console.log("✅ Remote track received!");
          if (remoteVideo.current) remoteVideo.current.srcObject = e.streams[0];
        };

        // ----- SIMPLE, FOOLPROOF OFFER LOGIC -----
        // After 1 second, EVERYONE sends an offer. The first one will connect,
        // the second will be ignored – but that's fine, connection happens.
        setTimeout(async () => {
          console.log("📞 Sending offer...");
          const offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          socket.emit("offer", { room: roomId, offer });
        }, 1000);
      } catch (err) {
        console.error("❌ Camera error:", err);
        alert("Camera error: " + err.message);
      }
    })();

    // 3. Signaling handlers
    socket.on("offer", async (offer) => {
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

    socket.on("answer", async (answer) => {
      console.log("📞 Received answer");
      if (!peerConnection.current) return;
      try {
        await peerConnection.current.setRemoteDescription(new RTCSessionDescription(answer));
      } catch (err) {
        console.error("❌ Answer error:", err);
      }
    });

    socket.on("ice_candidate", async (candidate) => {
      console.log("🧊 Received ICE candidate");
      if (!peerConnection.current) return;
      try {
        await peerConnection.current.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (err) {
        console.error("❌ ICE error:", err);
      }
    });

    socket.on("receive_message", (data) => {
      setMessages((prev) => [...prev, { text: data.message, from: "remote" }]);
    });

    return () => {
      socket.disconnect();
      if (localStreamRef.current) localStreamRef.current.getTracks().forEach((t) => t.stop());
      if (peerConnection.current) peerConnection.current.close();
    };
  }, [roomId]);

  const sendMessage = (e) => {
    e.preventDefault();
    if (messageInput.trim() && socketRef.current) {
      socketRef.current.emit("send_message", { room: roomId, message: messageInput });
      setMessages((prev) => [...prev, { text: messageInput, from: "local" }]);
      setMessageInput("");
    }
  };

  return (
    <div style={{ padding: "20px" }}>
      <h1>📹 Room: {roomId}</h1>
      <p style={{ background: "#ffeeba", padding: "10px" }}>
        ⚠️ Make sure BOTH tabs/devices use the <strong>EXACT SAME ROOM NAME</strong> in the URL!
      </p>
      <div style={{ display: "flex", gap: "20px" }}>
        <div>
          <h3>You</h3>
          <video ref={localVideo} autoPlay playsInline muted style={{ width: 400, height: 300, background: "#111" }} />
        </div>
        <div>
          <h3>Remote</h3>
          <video ref={remoteVideo} autoPlay playsInline style={{ width: 400, height: 300, background: "#111" }} />
        </div>
      </div>

      <div style={{ marginTop: 30 }}>
        <h3>💬 Chat</h3>
        <div style={{ border: "1px solid #ccc", height: 200, overflowY: "scroll", padding: 10 }}>
          {messages.map((msg, i) => (
            <div key={i} style={{ textAlign: msg.from === "local" ? "right" : "left", margin: "5px 0" }}>
              <span style={{ background: msg.from === "local" ? "#007bff" : "#e9ecef", color: msg.from === "local" ? "white" : "black", padding: "5px 10px", borderRadius: 15 }}>
                {msg.text}
              </span>
            </div>
          ))}
        </div>
        <form onSubmit={sendMessage} style={{ display: "flex", marginTop: 10 }}>
          <input value={messageInput} onChange={(e) => setMessageInput(e.target.value)} style={{ flex: 1, padding: 8 }} />
          <button type="submit" style={{ padding: "8px 15px", background: "#007bff", color: "white", border: "none" }}>Send</button>
        </form>
      </div>
    </div>
  );
}