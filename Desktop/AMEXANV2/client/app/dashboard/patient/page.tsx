'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { auth, db, storage } from '@/lib/firebase';
import {
  collection, query, where, onSnapshot, doc, addDoc, updateDoc,
  getDoc, serverTimestamp, orderBy, getDocs, arrayUnion, Timestamp
} from 'firebase/firestore';
import { ref as storageRef, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { signOut, onAuthStateChanged, updatePassword, EmailAuthProvider, reauthenticateWithCredential } from 'firebase/auth';
import { QRCodeSVG } from 'qrcode.react';

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════
interface Patient {
  uid: string; name: string; email: string; phone?: string; age?: number;
  gender?: string; bloodGroup?: string; condition?: string; universalId?: string;
  allergies?: string[]; emergencyContact?: string; photoUrl?: string;
  address?: string; dateOfBirth?: string; occupation?: string;
  nextOfKin?: string; insuranceProvider?: string; insuranceNumber?: string;
}
interface Doctor {
  id: string; name: string; specialty: string; clinic: string; photo?: string;
  bio?: string; qualifications?: string[]; yearsExperience?: number;
  languages?: string[]; rating?: number; reviewCount?: number;
  physicalAddress?: string; consultationHours?: string; tags?: string[];
  dedication?: string; price?: number; duration?: number;
  availableDays?: string[]; availableSlots?: string[];
  acceptsInsurance?: boolean; location?: string;
}
interface Service {
  id: string; specialty: string; clinic: string; price: number;
  description: string; doctorId: string; doctorName: string;
  duration: number; isAvailable: boolean; tags?: string[];
  rating?: number; yearsExperience?: number; location?: string;
  nextSlot?: any; bio?: string; languages?: string[];
  photo?: string; qualifications?: string[]; dedication?: string;
  physicalAddress?: string; consultationHours?: string;
  availableDays?: string[]; availableSlots?: string[];
  acceptsInsurance?: boolean; reviewCount?: number;
}
interface Appointment {
  id: string; doctorId: string; doctorName?: string; specialty?: string;
  serviceId: string; status: 'booked'|'active'|'completed'|'cancelled';
  date: any; scheduledDate?: any; scheduledTime?: string;
  consultationId?: string; prescriptions?: Prescription[]; notes?: string;
  patientNotes?: string; amount?: number; paymentStatus?: string;
  paymentRef?: string; paymentReceipt?: string; phone?: string;
  type?: 'telemedicine'|'in-person'; paidAt?: any; firstVisit?: boolean;
  paymentFailReason?: string;
}
interface Prescription {
  id?: string; medication: string; dosage: string; frequency: string;
  duration: string; addedAt: string; doctorName?: string;
  instructions?: string; refills?: number; taken?: Record<string, boolean>;
}
interface VitalReading {
  id: string; type: 'bp'|'glucose'|'weight'|'temp'|'pulse';
  value: string; systolic?: number; diastolic?: number; unit: string;
  recordedAt: any; note?: string;
}
interface Alert {
  id: string; title: string; body: string; severity: 'high'|'medium'|'low';
  read: boolean; createdAt: any; type?: string; actionUrl?: string;
}
interface LabResult {
  id: string; testName: string; result: string; unit?: string; referenceRange?: string;
  status: 'normal'|'abnormal'|'critical'; date: any; orderedBy?: string;
  reportUrl?: string; notes?: string;
}
interface HistoryEntry {
  id: string; section: string; content: string; date: any;
  authorName?: string; version?: number; signatureHash?: string;
  type: 'medical'|'social'|'family'|'allergy'|'surgery'|'encounter'|'lab'|'note';
}
interface DiseaseTarget {
  id: string; label: string; current?: string; target: string;
  status: 'on-target'|'off-target'|'warning'; unit?: string; icon: string;
}
interface Education {
  id: string; title: string; type: 'article'|'video'; url?: string;
  summary: string; condition: string; readTime?: string; imageUrl?: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const fmtDate = (ts: any) => {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-KE', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
};
const fmtShort = (ts: any) => {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-KE', { day: 'numeric', month: 'short' });
};
const getGreeting = () => { const h = new Date().getHours(); return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'; };
const bpCat = (s: number, d: number) => {
  if (s < 120 && d < 80) return { label: 'Normal', color: '#00d68f' };
  if (s < 130 && d < 80) return { label: 'Elevated', color: '#ffb020' };
  if (s < 140 || d < 90) return { label: 'High Stage 1', color: '#ff8c42' };
  return { label: 'High Stage 2', color: '#ff4560' };
};
const statusCfg: Record<string, { label: string; color: string; bg: string }> = {
  booked: { label: 'Upcoming', color: '#7c3aed', bg: 'rgba(124,58,237,0.12)' },
  active: { label: '● Live', color: '#00d68f', bg: 'rgba(0,214,143,0.12)' },
  completed: { label: 'Completed', color: '#64748b', bg: 'rgba(100,116,139,0.12)' },
  cancelled: { label: 'Cancelled', color: '#ff4560', bg: 'rgba(255,69,96,0.12)' },
};
const dayNames = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
function getDaysSince(ts: any): number {
  if (!ts) return 999;
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return Math.floor((Date.now() - d.getTime()) / 86400000);
}

// ═══════════════════════════════════════════════════════════════════════════
// COUNTDOWN HOOK
// ═══════════════════════════════════════════════════════════════════════════
function useCountdown(target: any) {
  const [label, setLabel] = useState('');
  useEffect(() => {
    if (!target) return;
    const d = target?.toDate ? target.toDate() : new Date(target);
    const tick = () => {
      const diff = d.getTime() - Date.now();
      if (diff <= 0) { setLabel('Now'); return; }
      const days = Math.floor(diff / 86400000);
      const hrs = Math.floor((diff % 86400000) / 3600000);
      const mins = Math.floor((diff % 3600000) / 60000);
      if (days > 0) setLabel(`${days}d ${hrs}h`);
      else if (hrs > 0) setLabel(`${hrs}h ${mins}m`);
      else setLabel(`${mins}m`);
    };
    tick();
    const id = setInterval(tick, 30000);
    return () => clearInterval(id);
  }, [target]);
  return label;
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYHERO STK PUSH
// ═══════════════════════════════════════════════════════════════════════════
async function initiateSTKFrontend(phone: string, amount: number, appointmentId: string, patientName: string, specialty: string) {
  const res = await fetch("/api/payhero/initiate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ phone, amount, appointmentId, patientName, specialty }),
  });

  const data = await res.json();
  if (!res.ok || data.success === false) throw new Error(data.message || "STK push failed");
  return data;
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESCRIPTION ADHERENCE CALENDAR
// ═══════════════════════════════════════════════════════════════════════════
function PrescriptionCalendar({ rx, patientId, apptId }: { rx: Prescription & { apptId: string }; patientId: string; apptId: string }) {
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(today.getDate() - 6 + i);
    return d;
  });

  const toggleDay = async (dateKey: string) => {
    const current = rx.taken?.[dateKey] ?? false;
    // Update in the appointments/prescriptions sub-collection
    const apptRef = doc(db, 'appointments', apptId);
    const apptSnap = await getDoc(apptRef);
    const prescriptions = apptSnap.data()?.prescriptions || [];
    const updated = prescriptions.map((p: any) =>
      p.medication === rx.medication ? { ...p, taken: { ...(p.taken || {}), [dateKey]: !current } } : p
    );
    await updateDoc(apptRef, { prescriptions: updated });
    // Also update in consultations if linked
    const consultSnap = await getDocs(query(collection(db, 'consultations'), where('appointmentId', '==', apptId)));
    if (!consultSnap.empty) {
      await updateDoc(doc(db, 'consultations', consultSnap.docs[0].id), { prescriptions: updated });
    }
  };

  return (
    <div className="cal-row">
      {days.map(d => {
        const key = d.toISOString().slice(0, 10);
        const taken = rx.taken?.[key];
        const isToday = d.toDateString() === today.toDateString();
        return (
          <button
            key={key}
            className={`cal-day ${taken ? 'cal-taken' : ''} ${isToday ? 'cal-today' : ''}`}
            onClick={() => toggleDay(key)}
            title={`${dayNames[d.getDay()]} ${d.getDate()} — ${taken ? 'Taken ✓' : 'Not taken'}`}
          >
            <span className="cal-dn">{dayNames[d.getDay()][0]}</span>
            <span className="cal-dd">{d.getDate()}</span>
            {taken && <span className="cal-check">✓</span>}
          </button>
        );
      })}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DOCTOR PROFILE DRAWER
// ═══════════════════════════════════════════════════════════════════════════
function DoctorProfileDrawer({ svc, onClose, onBook }: { svc: Service; onClose: () => void; onBook: () => void }) {
  return (
    <div className="drawer-overlay" onClick={onClose}>
      <div className="drawer" onClick={e => e.stopPropagation()}>
        <button className="drawer-close" onClick={onClose}>✕</button>
        <div className="dr-profile-hero" style={{
          background: `linear-gradient(135deg, #0f172a 0%, #1e2a4a 100%)`,
        }}>
          <div className="dr-profile-ava">
            {svc.photo
              ? <img src={svc.photo} alt={svc.doctorName} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }} />
              : <span style={{ fontSize: 36, fontWeight: 800 }}>{svc.doctorName[0]}</span>
            }
          </div>
          <div className="dr-profile-info">
            <h2 className="dr-profile-name">Dr. {svc.doctorName}</h2>
            <p className="dr-profile-spec">{svc.specialty} · {svc.clinic}</p>
            <div className="dr-profile-chips">
              {svc.rating && <span className="dr-chip">⭐ {svc.rating}/5 ({svc.reviewCount || 0} reviews)</span>}
              {svc.yearsExperience && <span className="dr-chip">🏆 {svc.yearsExperience} yrs exp</span>}
              {svc.acceptsInsurance && <span className="dr-chip">🏥 Accepts Insurance</span>}
            </div>
          </div>
        </div>

        <div className="drawer-body">
          {/* Price & Duration */}
          <div className="dr-price-row">
            <div className="dr-price-box">
              <span className="dr-price-label">Consultation Fee</span>
              <span className="dr-price-val">KES {svc.price?.toLocaleString()}</span>
            </div>
            <div className="dr-price-box">
              <span className="dr-price-label">Duration</span>
              <span className="dr-price-val">⏱ {svc.duration} min</span>
            </div>
            <div className="dr-price-box">
              <span className="dr-price-label">Type</span>
              <span className="dr-price-val">💻 Video</span>
            </div>
          </div>

          {/* Bio */}
          {svc.bio && (
            <div className="dr-section">
              <div className="dr-section-title">About</div>
              <p className="dr-section-body">{svc.bio}</p>
            </div>
          )}

          {/* Dedication message */}
          {svc.dedication && (
            <div className="dr-dedication">
              <span className="dr-quote">❝</span>
              <p>{svc.dedication}</p>
            </div>
          )}

          {/* Qualifications */}
          {svc.qualifications?.length ? (
            <div className="dr-section">
              <div className="dr-section-title">Qualifications</div>
              <div className="dr-qual-list">
                {svc.qualifications.map((q, i) => (
                  <div key={i} className="dr-qual-item">🎓 {q}</div>
                ))}
              </div>
            </div>
          ) : null}

          {/* Tags/Specialties */}
          {svc.tags?.length ? (
            <div className="dr-section">
              <div className="dr-section-title">Areas of Focus</div>
              <div className="dr-tags">
                {svc.tags.map((t, i) => <span key={i} className="dr-tag">{t}</span>)}
              </div>
            </div>
          ) : null}

          {/* Languages */}
          {svc.languages?.length ? (
            <div className="dr-section">
              <div className="dr-section-title">Languages</div>
              <div className="dr-tags">
                {svc.languages.map((l, i) => <span key={i} className="dr-tag">🌐 {l}</span>)}
              </div>
            </div>
          ) : null}

          {/* Location & Hours */}
          <div className="dr-section">
            <div className="dr-section-title">Clinic Details</div>
            <div className="dr-info-grid">
              {svc.physicalAddress && (
                <div className="dr-info-item">
                  <span className="dr-info-icon">📍</span>
                  <div>
                    <span className="dr-info-label">Physical Location</span>
                    <span className="dr-info-val">{svc.physicalAddress}</span>
                  </div>
                </div>
              )}
              {svc.consultationHours && (
                <div className="dr-info-item">
                  <span className="dr-info-icon">🕐</span>
                  <div>
                    <span className="dr-info-label">Consultation Hours</span>
                    <span className="dr-info-val">{svc.consultationHours}</span>
                  </div>
                </div>
              )}
              {svc.availableDays?.length ? (
                <div className="dr-info-item">
                  <span className="dr-info-icon">📅</span>
                  <div>
                    <span className="dr-info-label">Available Days</span>
                    <span className="dr-info-val">{svc.availableDays.join(', ')}</span>
                  </div>
                </div>
              ) : null}
            </div>
          </div>

          {/* Description */}
          {svc.description && (
            <div className="dr-section">
              <div className="dr-section-title">Service Description</div>
              <p className="dr-section-body">{svc.description}</p>
            </div>
          )}

          <button className="btn-book-full" onClick={onBook}>
            📅 Book Consultation — KES {svc.price?.toLocaleString()}
          </button>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOK APPOINTMENT MODAL
// ═══════════════════════════════════════════════════════════════════════════
function BookModal({ svc, patient, onClose }: { svc: Service; patient: Patient; onClose: () => void }) {
  const [step, setStep] = useState<'slot'|'details'|'pay'|'done'>('slot');
  const [concern, setConcern] = useState('');
  const [phone, setPhone] = useState(patient.phone || '');
  const [selectedSlot, setSelectedSlot] = useState('');
  const [selectedDate, setSelectedDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [apptId, setApptId] = useState('');
  const [retrying, setRetrying] = useState(false);
  const [existingApptId, setExistingApptId] = useState('');

  // Generate slots for next 7 days
  const slots = svc.availableSlots || ['09:00','09:30','10:00','10:30','11:00','11:30','14:00','14:30','15:00','15:30','16:00'];
  const next7Days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(); d.setDate(d.getDate() + 1 + i);
    const dayName = dayNames[d.getDay()];
    const isAvailable = !svc.availableDays?.length || svc.availableDays.includes(dayName);
    return { date: d, key: d.toISOString().slice(0, 10), label: `${dayName} ${d.getDate()}`, available: isAvailable };
  }).filter(d => d.available);

  const handleBook = async () => {
    if (!concern.trim()) { setError('Please describe your concern.'); return; }
    if (!selectedSlot || !selectedDate) { setError('Please select a date and time.'); return; }
    setLoading(true); setError('');
    try {
      // Check if patient has previously visited this doctor
      const prevVisits = await getDocs(query(
        collection(db, 'appointments'),
        where('patientId', '==', patient.uid),
        where('doctorId', '==', svc.doctorId),
        where('status', 'in', ['completed', 'booked'])
      ));
      const isFirstVisit = prevVisits.empty;
      const scheduledDateTime = new Date(`${selectedDate}T${selectedSlot}:00`);

      const ref = await addDoc(collection(db, 'appointments'), {
        patientId: patient.uid, patientName: patient.name, patientEmail: patient.email,
        doctorId: svc.doctorId, doctorName: svc.doctorName, serviceId: svc.id,
        specialty: svc.specialty, status: 'booked',
        date: serverTimestamp(),
        scheduledDate: Timestamp.fromDate(scheduledDateTime),
        scheduledTime: selectedSlot,
        patientNotes: concern, prescriptions: [], notes: '',
        paymentStatus: 'pending', amount: svc.price, type: 'telemedicine',
        firstVisit: isFirstVisit,
      });
      setApptId(ref.id);
      setStep('pay');
    } catch (e: any) { setError(e.message); }
    setLoading(false);
  };

  const handlePay = async (targetApptId?: string) => {
  const id = targetApptId || apptId;

  // Validate Safaricom number
  if (!phone.match(/^(07|01|\+2547|\+2541)\d{7,8}$/)) {
    setError('Enter a valid Safaricom number (e.g. 0712345678)');
    return;
  }

  setLoading(true);
  setError('');

  try {
    // Call server-side API instead of client-side initiateSTK
    const res = await fetch('/api/payhero/initiate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone,
        amount: svc.price,
        appointmentId: id,
        patientName: patient.name,
        specialty: svc.specialty,
      }),
    });

    const data = await res.json();
    if (!res.ok || !data.success) throw new Error(data.message || 'STK push failed');

    // Update Firestore with payment reference
    await updateDoc(doc(db, 'appointments', id), {
      paymentRef: data.data?.reference || data.data?.CheckoutRequestID || '',
      paymentStatus: 'processing',
      phone,
    });

    setStep('done');
  } catch (e: any) {
    setError(e.message);
    setExistingApptId(id); // Allow retry
  }

  setLoading(false);
};

  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()}>
        <div className="modal-hd">
          <div>
            <h3 className="modal-ht">{svc.specialty}</h3>
            <p className="modal-hs">Dr. {svc.doctorName} · {svc.clinic}</p>
          </div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        {/* Steps bar */}
        <div className="steps-bar">
          {['Date & Time','Details','Payment','Confirmed'].map((s, i) => {
            const stepIdx = step === 'slot' ? 0 : step === 'details' ? 1 : step === 'pay' ? 2 : 3;
            return (
              <div key={s} className="step-wrap">
                <div className={`step-num ${i <= stepIdx ? 'step-on' : ''}`}>{i < stepIdx ? '✓' : i + 1}</div>
                <span className="step-text">{s}</span>
                {i < 3 && <div className={`step-line ${i < stepIdx ? 'step-line-on' : ''}`} />}
              </div>
            );
          })}
        </div>

        {step === 'slot' && (
          <div className="modal-body">
            <div className="field-col">
              <label className="field-lbl">Select Date</label>
              <div className="slot-days">
                {next7Days.map(d => (
                  <button key={d.key} className={`slot-day ${selectedDate === d.key ? 'slot-on' : ''}`}
                    onClick={() => setSelectedDate(d.key)}>
                    {d.label}
                  </button>
                ))}
              </div>
            </div>
            {selectedDate && (
              <div className="field-col">
                <label className="field-lbl">Select Time</label>
                <div className="slot-times">
                  {slots.map(s => (
                    <button key={s} className={`slot-time ${selectedSlot === s ? 'slot-on' : ''}`}
                      onClick={() => setSelectedSlot(s)}>
                      {s}
                    </button>
                  ))}
                </div>
              </div>
            )}
            {error && <div className="err-box">{error}</div>}
            <button className="btn-cta" onClick={() => {
              if (!selectedDate || !selectedSlot) { setError('Please pick a date and time.'); return; }
              setError(''); setStep('details');
            }}>
              Continue →
            </button>
          </div>
        )}

        {step === 'details' && (
          <div className="modal-body">
            <div className="booking-summary">
              <span>📅 {new Date(selectedDate).toLocaleDateString('en-KE', { weekday: 'long', day: 'numeric', month: 'long' })}</span>
              <span>⏰ {selectedSlot}</span>
              <span>💰 KES {svc.price.toLocaleString()}</span>
            </div>
            <div className="field-col">
              <label className="field-lbl">Describe your concern *</label>
              <textarea className="field-ta" rows={4} value={concern}
                onChange={e => setConcern(e.target.value)}
                placeholder="What symptoms are you experiencing? How long? Any previous treatments?" />
            </div>
            {error && <div className="err-box">{error}</div>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn-secondary" onClick={() => setStep('slot')}>← Back</button>
              <button className="btn-cta" onClick={handleBook} disabled={loading}>
                {loading ? 'Booking…' : 'Continue to Payment →'}
              </button>
            </div>
          </div>
        )}

        {step === 'pay' && (
          <div className="modal-body">
            <div className="pay-center">
              <div className="pay-amt">KES {svc.price.toLocaleString()}</div>
              <p className="pay-sub">M-Pesa STK Push</p>
            </div>
            <div className="mpesa-pill">
              <span style={{ fontSize: 24 }}>📱</span>
              <span style={{ color: '#16a34a', fontWeight: 800, fontSize: 17 }}>M-PESA</span>
            </div>
            <div className="field-col">
              <label className="field-lbl">Safaricom Number *</label>
              <input className="field-inp" type="tel" value={phone}
                onChange={e => setPhone(e.target.value)} placeholder="0712 345 678" />
            </div>
            <p className="pay-note">📌 You'll receive an STK push on your phone. Enter your M-Pesa PIN to complete payment.</p>
            {error && (
              <div className="err-box">
                {error}
                {existingApptId && (
                  <button className="retry-btn" onClick={() => handlePay(existingApptId)}>
                    🔄 Retry Payment
                  </button>
                )}
              </div>
            )}
            <button className="btn-cta" onClick={() => handlePay()} disabled={loading}>
              {loading ? 'Sending prompt…' : `💳 Pay KES ${svc.price.toLocaleString()}`}
            </button>
          </div>
        )}

        {step === 'done' && (
          <div className="modal-body" style={{ textAlign: 'center', padding: '32px 22px' }}>
            <div style={{ fontSize: 64, marginBottom: 16 }}>🎉</div>
            <h4 style={{ fontWeight: 800, fontSize: 20, color: 'var(--text)', marginBottom: 10 }}>Appointment Booked!</h4>
            <p style={{ color: 'var(--text2)', fontSize: 14, lineHeight: 1.8, marginBottom: 8 }}>
              Payment is being processed. Dr. {svc.doctorName} will be available on<br />
              <strong>{new Date(selectedDate).toLocaleDateString('en-KE', { weekday: 'long', day: 'numeric', month: 'long' })} at {selectedSlot}</strong>
            </p>
            <p style={{ color: 'var(--accent)', fontSize: 13, marginBottom: 28 }}>
              A receipt will appear in Payments once confirmed.
            </p>
            <button className="btn-cta" onClick={onClose}>Done</button>
          </div>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// LOG VITAL MODAL
// ═══════════════════════════════════════════════════════════════════════════
function LogVitalModal({ patient, onClose, onSaved }: { patient: Patient; onClose: () => void; onSaved: () => void }) {
  const [type, setType] = useState<'bp'|'glucose'|'weight'|'temp'|'pulse'>('bp');
  const [sys, setSys] = useState(''); const [dia, setDia] = useState('');
  const [value, setValue] = useState(''); const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);
  const types = [
    { id: 'bp', label: 'Blood Pressure', icon: '❤️', unit: 'mmHg' },
    { id: 'glucose', label: 'Blood Glucose', icon: '🩸', unit: 'mmol/L' },
    { id: 'weight', label: 'Weight', icon: '⚖️', unit: 'kg' },
    { id: 'temp', label: 'Temperature', icon: '🌡️', unit: '°C' },
    { id: 'pulse', label: 'Pulse Rate', icon: '💓', unit: 'bpm' },
  ];
  const save = async () => {
    setSaving(true);
    try {
      const unit = types.find(v => v.id === type)?.unit || '';
      const data: any = { patientId: patient.uid, type, unit, recordedAt: serverTimestamp(), note };
      if (type === 'bp') { data.systolic = Number(sys); data.diastolic = Number(dia); data.value = `${sys}/${dia}`; }
      else { data.value = value; }
      await addDoc(collection(db, 'vitals'), data);
      onSaved(); onClose();
    } catch (e) { console.error(e); }
    setSaving(false);
  };
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
        <div className="modal-hd"><h3 className="modal-ht">📊 Log Vital Sign</h3><button className="modal-close" onClick={onClose}>✕</button></div>
        <div className="modal-body">
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {types.map(v => (
              <button key={v.id} onClick={() => setType(v.id as any)} className={`vital-chip ${type === v.id ? 'vital-chip-on' : ''}`}>
                {v.icon} {v.label}
              </button>
            ))}
          </div>
          {type === 'bp' ? (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              <div className="field-col"><label className="field-lbl">Systolic</label><input className="field-inp" type="number" value={sys} onChange={e => setSys(e.target.value)} placeholder="120" /></div>
              <div className="field-col"><label className="field-lbl">Diastolic</label><input className="field-inp" type="number" value={dia} onChange={e => setDia(e.target.value)} placeholder="80" /></div>
            </div>
          ) : (
            <div className="field-col">
              <label className="field-lbl">Value ({types.find(v => v.id === type)?.unit})</label>
              <input className="field-inp" type="number" value={value} onChange={e => setValue(e.target.value)} />
            </div>
          )}
          <div className="field-col"><label className="field-lbl">Note (optional)</label><input className="field-inp" value={note} onChange={e => setNote(e.target.value)} placeholder="e.g. After morning walk" /></div>
          <button className="btn-cta" onClick={save} disabled={saving}>{saving ? 'Saving…' : '💾 Save Reading'}</button>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SMARTCARD MODAL
// ═══════════════════════════════════════════════════════════════════════════
function SmartcardModal({ patient, onClose }: { patient: Patient; onClose: () => void }) {
  const uid = patient.universalId || `AMX-${patient.uid.slice(0, 8).toUpperCase()}`;
  const qrValue = typeof window !== 'undefined' ? `${window.location.origin}/patient/${uid}` : uid;
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 380 }}>
        <div className="modal-hd"><h3 className="modal-ht">🪪 Patient Smartcard</h3><button className="modal-close" onClick={onClose}>✕</button></div>
        <div className="modal-body">
          <div className="smartcard">
            <div className="sc-top">
              <div className="sc-avatar">{patient.photoUrl ? <img src={patient.photoUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }} /> : patient.name[0]}</div>
              <div style={{ flex: 1 }}>
                <div className="sc-name">{patient.name}</div>
                <div className="sc-id">ID: {uid}</div>
              </div>
              <div style={{ fontSize: 24 }}>⚕️</div>
            </div>
            <div className="sc-grid">
              {[['Blood Group', patient.bloodGroup || '—'], ['Age', patient.age ? `${patient.age} yrs` : '—'], ['Gender', patient.gender || '—'], ['Condition', patient.condition || '—']].map(([k, v]) => (
                <div key={k} className="sc-item"><span className="sc-key">{k}</span><span className="sc-val">{v}</span></div>
              ))}
            </div>
            {patient.allergies?.length ? <div className="sc-allergy">⚠️ Allergies: {patient.allergies.join(', ')}</div> : null}
            {patient.emergencyContact && <div className="sc-emergency">🆘 Emergency: {patient.emergencyContact}</div>}
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', margin: '16px 0 6px', background: 'white', padding: 12, borderRadius: 12 }}>
            <QRCodeSVG value={qrValue} size={160} bgColor="#fff" fgColor="#0f172a" level="H" />
          </div>
          <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--muted)' }}>Scan to instantly share medical info with any doctor</p>
          <button className="btn-secondary" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIAGE MODAL
// ═══════════════════════════════════════════════════════════════════════════
function TriageModal({ onClose, onDone }: { onClose: () => void; onDone: (sp: string) => void }) {
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<string[]>([]);
  const questions = [
    { q: "What's your main concern today?", opts: ['Heart / Chest pain','Blood sugar / Diabetes','Breathing problems','Mental health','Skin condition','Bone / Joint pain',"Child's health",'Eye / Vision','Ear / Nose / Throat','Reproductive / Gynae','Dental / Oral','General check-up','Other'] },
    { q: 'How long have you had this?', opts: ['Started today','A few days','A few weeks','Over a month','Chronic condition (years)'] },
    { q: 'How severe is it right now?', opts: ['Mild — manageable','Moderate — affecting daily life','Severe — need urgent help','🚨 Emergency — life-threatening'] },
    { q: 'Have you seen a doctor for this before?', opts: ['No — first time','Yes — follow-up visit','Yes — but different hospital','Currently on medication for it'] },
  ];
  const specialtyMap: Record<string, string> = {
    'Heart / Chest pain':'Cardiology','Blood sugar / Diabetes':'Endocrinology','Breathing problems':'Pulmonology',
    'Mental health':'Mental Health','Skin condition':'Dermatology','Bone / Joint pain':'Orthopedics',
    "Child's health":'Pediatrics','Eye / Vision':'Ophthalmology','Ear / Nose / Throat':'ENT',
    'Reproductive / Gynae':'Gynecology','Dental / Oral':'Dental','General check-up':'General',Other:'General',
  };
  const select = (ans: string) => {
    if (ans === '🚨 Emergency — life-threatening') { alert('🚨 EMERGENCY: Call 999 or 112 immediately!'); onClose(); return; }
    const next = [...answers, ans];
    if (step === questions.length - 1) { onDone(specialtyMap[next[0]] || 'General'); }
    else { setAnswers(next); setStep(s => s + 1); }
  };
  const q = questions[step];
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
        <div className="modal-hd"><h3 className="modal-ht">🔍 Smart Triage</h3><button className="modal-close" onClick={onClose}>✕</button></div>
        <div className="modal-body">
          <div className="triage-bar"><div className="triage-prog" style={{ width: `${(step / questions.length) * 100}%` }} /></div>
          <p className="triage-step">Question {step + 1} of {questions.length}</p>
          <h4 className="triage-q">{q.q}</h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {q.opts.map(opt => (
              <button key={opt} className={`triage-opt ${opt.includes('🚨') ? 'triage-emergency' : ''}`} onClick={() => select(opt)}>{opt}</button>
            ))}
          </div>
          {step > 0 && <button className="btn-secondary" onClick={() => setStep(s => s - 1)}>← Back</button>}
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY MODAL
// ═══════════════════════════════════════════════════════════════════════════
function EmergencyModal({ onClose, patientId }: { onClose: () => void; patientId: string }) {
  const alert911 = async () => {
    await addDoc(collection(db, 'alerts'), {
      recipientId: 'all-doctors',
      patientId, type: 'emergency',
      title: '🚨 Patient Emergency Alert',
      body: 'Patient has triggered an emergency alert and may need immediate assistance.',
      severity: 'high', read: false, createdAt: serverTimestamp(),
    });
    window.alert('Emergency alert sent to your care team!');
    onClose();
  };
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 400, textAlign: 'center' }}>
        <div style={{ padding: 32 }}>
          <div style={{ fontSize: 52, marginBottom: 16 }}>🚨</div>
          <h3 style={{ fontSize: 22, fontWeight: 800, color: '#ff4560', marginBottom: 12 }}>Emergency</h3>
          <p style={{ color: 'var(--text2)', marginBottom: 24, lineHeight: 1.7 }}>
            For life-threatening emergencies, call emergency services immediately.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <a href="tel:999" className="btn-cta" style={{ background: '#ff4560', textDecoration: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>📞 Call 999</a>
            <a href="tel:112" className="btn-cta" style={{ background: '#ef4444', textDecoration: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>📞 Call 112</a>
            <button className="btn-secondary" onClick={alert911}>🔔 Alert My Care Team</button>
            <button className="btn-secondary" onClick={onClose}>Close</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS PANEL (Editable, uploads to Firestore + Storage)
// ═══════════════════════════════════════════════════════════════════════════
function SettingsPanel({ patient, onUpdate }: { patient: Patient; onUpdate: (p: Partial<Patient>) => void }) {
  const [form, setForm] = useState({ ...patient });
  const [pwd, setPwd] = useState(''); const [oldPwd, setOldPwd] = useState('');
  const [pwdMsg, setPwdMsg] = useState(''); const [saving, setSaving] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const [msg, setMsg] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    setPhotoUploading(true);
    const sRef = storageRef(storage, `patients/${patient.uid}/profile/${Date.now()}_${file.name}`);
    const task = uploadBytesResumable(sRef, file);
    task.on('state_changed', null, err => { console.error(err); setPhotoUploading(false); },
      async () => {
        const url = await getDownloadURL(task.snapshot.ref);
        await updateDoc(doc(db, 'users', patient.uid), { photoUrl: url });
        setForm(f => ({ ...f, photoUrl: url }));
        onUpdate({ photoUrl: url });
        setPhotoUploading(false);
        setMsg('Profile photo updated!');
      });
  };

  const handleSave = async () => {
    setSaving(true); setMsg('');
    try {
      const updates = {
        name: form.name, phone: form.phone, age: form.age,
        gender: form.gender, bloodGroup: form.bloodGroup,
        address: form.address, occupation: form.occupation,
        nextOfKin: form.nextOfKin, emergencyContact: form.emergencyContact,
        insuranceProvider: form.insuranceProvider, insuranceNumber: form.insuranceNumber,
        allergies: typeof form.allergies === 'string' ? (form.allergies as any).split(',').map((s: string) => s.trim()).filter(Boolean) : form.allergies,
        updatedAt: serverTimestamp(),
      };
      await updateDoc(doc(db, 'users', patient.uid), updates);
      onUpdate(updates);
      setMsg('Profile saved successfully!');
    } catch (e: any) { setMsg('Error: ' + e.message); }
    setSaving(false);
  };

  const handlePwdChange = async () => {
    if (!oldPwd || !pwd || pwd.length < 8) { setPwdMsg('Password must be at least 8 characters.'); return; }
    try {
      const user = auth.currentUser!;
      const cred = EmailAuthProvider.credential(user.email!, oldPwd);
      await reauthenticateWithCredential(user, cred);
      await updatePassword(user, pwd);
      setPwdMsg('Password updated!'); setPwd(''); setOldPwd('');
    } catch (e: any) { setPwdMsg('Error: ' + e.message); }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Profile Photo */}
      <div className="settings-card">
        <div className="settings-card-title">🖼️ Profile Photo</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <div className="settings-avatar">
            {form.photoUrl ? <img src={form.photoUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }} /> : form.name[0]}
          </div>
          <div>
            <button className="btn-sm-accent" onClick={() => fileRef.current?.click()} disabled={photoUploading}>
              {photoUploading ? 'Uploading…' : '📸 Change Photo'}
            </button>
            <p style={{ fontSize: 11, color: 'var(--muted)', marginTop: 6 }}>JPG, PNG. Max 5MB.</p>
            <input ref={fileRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handlePhotoUpload} />
          </div>
        </div>
      </div>

      {/* Personal Info */}
      <div className="settings-card">
        <div className="settings-card-title">👤 Personal Information</div>
        <div className="settings-grid">
          {[
            { label: 'Full Name', key: 'name', type: 'text' },
            { label: 'Phone Number', key: 'phone', type: 'tel' },
            { label: 'Age', key: 'age', type: 'number' },
            { label: 'Date of Birth', key: 'dateOfBirth', type: 'date' },
            { label: 'Occupation', key: 'occupation', type: 'text' },
            { label: 'Address', key: 'address', type: 'text' },
          ].map(f => (
            <div key={f.key} className="field-col">
              <label className="field-lbl">{f.label}</label>
              <input className="field-inp" type={f.type} value={(form as any)[f.key] || ''}
                onChange={e => setForm(p => ({ ...p, [f.key]: e.target.value }))} />
            </div>
          ))}
          <div className="field-col">
            <label className="field-lbl">Gender</label>
            <select className="field-inp" value={form.gender || ''} onChange={e => setForm(p => ({ ...p, gender: e.target.value }))}>
              <option value="">Select</option>
              <option>Male</option><option>Female</option><option>Other</option>
            </select>
          </div>
          <div className="field-col">
            <label className="field-lbl">Blood Group</label>
            <select className="field-inp" value={form.bloodGroup || ''} onChange={e => setForm(p => ({ ...p, bloodGroup: e.target.value }))}>
              <option value="">Select</option>
              {['A+','A-','B+','B-','AB+','AB-','O+','O-'].map(g => <option key={g}>{g}</option>)}
            </select>
          </div>
        </div>
      </div>

      {/* Medical Info */}
      <div className="settings-card">
        <div className="settings-card-title">🏥 Medical & Emergency</div>
        <div className="settings-grid">
          <div className="field-col">
            <label className="field-lbl">Known Allergies (comma-separated)</label>
            <input className="field-inp" value={Array.isArray(form.allergies) ? form.allergies.join(', ') : form.allergies || ''}
              onChange={e => setForm(p => ({ ...p, allergies: e.target.value as any }))} placeholder="e.g. Penicillin, Peanuts" />
          </div>
          <div className="field-col">
            <label className="field-lbl">Emergency Contact</label>
            <input className="field-inp" value={form.emergencyContact || ''}
              onChange={e => setForm(p => ({ ...p, emergencyContact: e.target.value }))} placeholder="Name & Phone" />
          </div>
          <div className="field-col">
            <label className="field-lbl">Next of Kin</label>
            <input className="field-inp" value={form.nextOfKin || ''}
              onChange={e => setForm(p => ({ ...p, nextOfKin: e.target.value }))} />
          </div>
          <div className="field-col">
            <label className="field-lbl">Insurance Provider</label>
            <input className="field-inp" value={form.insuranceProvider || ''}
              onChange={e => setForm(p => ({ ...p, insuranceProvider: e.target.value }))} />
          </div>
          <div className="field-col">
            <label className="field-lbl">Insurance Number</label>
            <input className="field-inp" value={form.insuranceNumber || ''}
              onChange={e => setForm(p => ({ ...p, insuranceNumber: e.target.value }))} />
          </div>
        </div>
      </div>

      {msg && <div className={`msg-banner ${msg.includes('Error') ? 'msg-err' : 'msg-ok'}`}>{msg}</div>}
      <button className="btn-cta" onClick={handleSave} disabled={saving}>
        {saving ? 'Saving…' : '💾 Save All Changes'}
      </button>

      {/* Password Change */}
      <div className="settings-card">
        <div className="settings-card-title">🔒 Change Password</div>
        <div className="settings-grid">
          <div className="field-col">
            <label className="field-lbl">Current Password</label>
            <input className="field-inp" type="password" value={oldPwd} onChange={e => setOldPwd(e.target.value)} />
          </div>
          <div className="field-col">
            <label className="field-lbl">New Password (min 8 chars)</label>
            <input className="field-inp" type="password" value={pwd} onChange={e => setPwd(e.target.value)} />
          </div>
        </div>
        {pwdMsg && <div className={`msg-banner ${pwdMsg.includes('Error') ? 'msg-err' : 'msg-ok'}`} style={{ marginTop: 8 }}>{pwdMsg}</div>}
        <button className="btn-secondary" onClick={handlePwdChange} style={{ marginTop: 12, width: 'auto', padding: '10px 20px' }}>
          🔑 Update Password
        </button>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENTS PANEL
// ═══════════════════════════════════════════════════════════════════════════
function PaymentsPanel({ appointments, patient }: { appointments: Appointment[]; patient: Patient }) {
  const [phone, setPhone] = useState(patient.phone || '');
  const [paying, setPaying] = useState<string | null>(null);
  const [payMsg, setPayMsg] = useState('');

  const pending = appointments.filter(a => a.paymentStatus === 'pending' || a.paymentStatus === 'failed');
  const paid = appointments.filter(a => a.paymentStatus === 'paid');

  const retryPay = async (appt: Appointment) => {
  // Validate Safaricom number
  if (!phone.match(/^(07|01|\+2547|\+2541)\d{7,8}$/)) {
    setPayMsg('Enter valid Safaricom number');
    return;
  }

  setPaying(appt.id);
  setPayMsg('');

  try {
    // Call server-side API route
    const res = await fetch('/api/payhero/initiate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone,
        amount: appt.amount || 0,
        appointmentId: appt.id,
        patientName: patient.name,
        specialty: appt.specialty || 'Consultation',
      }),
    });

    const data = await res.json();

    if (!res.ok || !data.success) {
      throw new Error(data.message || 'STK push failed');
    }

    // Update Firestore
    await updateDoc(doc(db, 'appointments', appt.id), {
      paymentRef: data.data?.reference || data.data?.CheckoutRequestID || '',
      paymentStatus: 'processing',
      phone,
    });

    setPayMsg('STK push sent! Check your phone.');
  } catch (e: any) {
    setPayMsg('Error: ' + e.message);
  }

  setPaying(null);
};

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {pending.length > 0 && (
        <div className="panel">
          <div className="panel-hd">
            <div className="panel-title">⚠️ Outstanding Payments</div>
            <span className="count-badge" style={{ background: 'rgba(255,176,32,.15)', color: 'var(--amber)' }}>{pending.length}</span>
          </div>
          <div className="field-col" style={{ marginBottom: 12 }}>
            <label className="field-lbl">M-Pesa Number</label>
            <input className="field-inp" type="tel" value={phone} onChange={e => setPhone(e.target.value)} placeholder="0712 345 678" style={{ maxWidth: 240 }} />
          </div>
          {payMsg && <div className="msg-banner msg-ok" style={{ marginBottom: 10 }}>{payMsg}</div>}
          {pending.map(a => (
            <div key={a.id} className="pay-pending-card">
              <div>
                <div style={{ fontWeight: 700, fontSize: 14 }}>{a.specialty || 'Consultation'} — Dr. {a.doctorName}</div>
                <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 2 }}>{fmtDate(a.scheduledDate || a.date)}</div>
                {a.paymentFailReason && <div style={{ fontSize: 11, color: 'var(--red)', marginTop: 2 }}>Failed: {a.paymentFailReason}</div>}
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontWeight: 900, fontSize: 16, color: 'var(--accent)', fontFamily: 'monospace' }}>KES {(a.amount || 0).toLocaleString()}</div>
                <button className="btn-sm-accent" onClick={() => retryPay(a)} disabled={paying === a.id} style={{ marginTop: 6 }}>
                  {paying === a.id ? 'Sending…' : '💳 Pay Now'}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="panel">
        <div className="panel-hd">
          <div className="panel-title">✅ Payment History</div>
          <span className="count-badge">{paid.length}</span>
        </div>
        {paid.length === 0 ? (
          <div className="empty-sm"><div style={{ fontSize: 32 }}>🧾</div><p>No payment history yet.</p></div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {paid.map(a => (
              <div key={a.id} className="pay-history-card">
                <div>
                  <div style={{ fontWeight: 700, fontSize: 13 }}>{a.specialty} — Dr. {a.doctorName}</div>
                  <div style={{ fontSize: 11, color: 'var(--muted)', fontFamily: 'monospace', marginTop: 2 }}>
                    Ref: {a.paymentRef || '—'} · {fmtDate(a.paidAt || a.date)}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontWeight: 800, color: 'var(--green)', fontFamily: 'monospace' }}>KES {(a.amount || 0).toLocaleString()}</div>
                  <span style={{ fontSize: 10, color: 'var(--green)', fontWeight: 700 }}>✓ PAID</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CLINICAL HISTORY PANEL
// ═══════════════════════════════════════════════════════════════════════════
function ClinicalHistoryPanel({ patientId, patient }: { patientId: string; patient: Patient }) {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');
  const [filter, setFilter] = useState('all');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'clinical_history'), where('patientId', '==', patientId), orderBy('date', 'desc')),
      snap => setHistory(snap.docs.map(d => ({ id: d.id, ...d.data() } as HistoryEntry)))
    );
    return () => unsub();
  }, [patientId]);

  const saveEdit = async (id: string) => {
    setSaving(true);
    await updateDoc(doc(db, 'clinical_history', id), {
      content: editContent,
      patientEdited: true,
      patientEditedAt: serverTimestamp(),
      version: (history.find(h => h.id === id)?.version || 1) + 0.1,
    });
    setEditingId(null); setSaving(false);
  };

  const types = ['all', 'encounter', 'lab', 'medical', 'allergy', 'surgery', 'family', 'social', 'note'];
  const filtered = filter === 'all' ? history : history.filter(h => h.type === filter);

  const typeIcon: Record<string, string> = {
    encounter: '🩺', lab: '🔬', medical: '📋', allergy: '⚠️',
    surgery: '🔪', family: '👨‍👩‍👦', social: '🌍', note: '📝', default: '📄',
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div className="panel">
        <div className="panel-hd">
          <div className="panel-title">📋 Clinical History Timeline</div>
          <span className="count-badge">{history.length} entries</span>
        </div>
        <div className="filter-bar">
          {types.map(t => (
            <button key={t} className={`filter-pill ${filter === t ? 'filter-on' : ''}`} onClick={() => setFilter(t)}>
              {t === 'all' ? '🗂️ All' : `${typeIcon[t] || '📄'} ${t[0].toUpperCase() + t.slice(1)}`}
            </button>
          ))}
        </div>
        {filtered.length === 0 ? (
          <div className="empty-sm"><div style={{ fontSize: 32 }}>📭</div><p>No history entries yet. They'll appear after doctor consultations.</p></div>
        ) : (
          <div className="timeline">
            {filtered.map(h => (
              <div key={h.id} className="timeline-entry">
                <div className="timeline-dot">{typeIcon[h.type] || '📄'}</div>
                <div className="timeline-content" onClick={() => setExpanded(expanded === h.id ? null : h.id)}>
                  <div className="timeline-hd">
                    <div>
                      <div className="timeline-section">{h.section}</div>
                      <div className="timeline-meta">
                        {fmtDate(h.date)} · {h.authorName ? `By Dr. ${h.authorName}` : 'System'} · v{(h.version || 1).toFixed(1)}
                      </div>
                    </div>
                    <span className="timeline-type-badge">{h.type}</span>
                  </div>
                  {expanded === h.id && (
                    <div className="timeline-body">
                      {editingId === h.id ? (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          <textarea className="field-ta" value={editContent} onChange={e => setEditContent(e.target.value)} rows={4} />
                          <div style={{ display: 'flex', gap: 8 }}>
                            <button className="btn-sm-accent" onClick={() => saveEdit(h.id)} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
                            <button className="btn-secondary" style={{ width: 'auto', padding: '6px 12px' }} onClick={() => setEditingId(null)}>Cancel</button>
                          </div>
                        </div>
                      ) : (
                        <>
                          <p style={{ fontSize: 13, color: 'var(--text2)', lineHeight: 1.7 }}>{h.content}</p>
                          {h.signatureHash && <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 8, fontFamily: 'monospace' }}>Signature: {h.signatureHash.slice(0, 24)}…</div>}
                          <button className="btn-secondary" style={{ marginTop: 10, width: 'auto', padding: '6px 14px', fontSize: 12 }}
                            onClick={(e) => { e.stopPropagation(); setEditingId(h.id); setEditContent(h.content); }}>
                            ✏️ Request edit
                          </button>
                        </>
                      )}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DISEASE TOOLS PANEL (Real-time, from doctor)
// ═══════════════════════════════════════════════════════════════════════════
function DiseaseToolsPanel({ patientId, condition, vitals, onLogVital }: {
  patientId: string; condition?: string; vitals: VitalReading[]; onLogVital: () => void;
}) {
  const [targets, setTargets] = useState<DiseaseTarget[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'disease_targets'), where('patientId', '==', patientId)),
      snap => setTargets(snap.docs.map(d => ({ id: d.id, ...d.data() } as DiseaseTarget)))
    );
    return () => unsub();
  }, [patientId]);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'alerts'), where('patientId', '==', patientId), where('read', '==', false), orderBy('createdAt', 'desc')),
      snap => setAlerts(snap.docs.map(d => ({ id: d.id, ...d.data() } as Alert)))
    );
    return () => unsub();
  }, [patientId]);

  const dismissAlert = async (id: string) => {
    await updateDoc(doc(db, 'alerts', id), { read: true });
  };

  const latestBP = vitals.find(v => v.type === 'bp');
  const latestGlucose = vitals.find(v => v.type === 'glucose');
  const conditionTargets = targets.length ? targets : condition === 'Hypertension' ? [
    { id: 'bp', label: 'Blood Pressure', target: '<130/80 mmHg', icon: '❤️', status: (latestBP && latestBP.systolic! < 130) ? 'on-target' as const : 'off-target' as const, current: latestBP ? `${latestBP.systolic}/${latestBP.diastolic}` : undefined, unit: 'mmHg' },
  ] : condition === 'Diabetes' ? [
    { id: 'glc', label: 'Blood Glucose', target: '4.0–7.0 mmol/L', icon: '🩸', status: (latestGlucose && parseFloat(latestGlucose.value) <= 7) ? 'on-target' as const : 'off-target' as const, current: latestGlucose?.value, unit: 'mmol/L' },
  ] : [];

  if (!condition) return null;

  return (
    <div className="disease-panel">
      <div className="disease-panel-hd">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div className="disease-icon">🎯</div>
          <div>
            <div className="disease-title">{condition} Management</div>
            <div className="disease-sub">Real-time monitoring · Updated by your doctor</div>
          </div>
        </div>
        <button className="btn-sm-accent" onClick={onLogVital}>+ Log Reading</button>
      </div>

      {/* Alerts */}
      {alerts.filter(a => a.severity === 'high').length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 16 }}>
          {alerts.filter(a => a.severity === 'high').slice(0, 3).map(a => (
            <div key={a.id} className="disease-alert">
              <span>🚨 <strong>{a.title}</strong> — {a.body}</span>
              <button className="dismiss-btn" onClick={() => dismissAlert(a.id)}>✕</button>
            </div>
          ))}
        </div>
      )}

      {/* Targets */}
      <div className="targets-grid">
        {conditionTargets.map(t => (
          <div key={t.id} className={`target-card target-${t.status}`}>
            <div className="target-icon">{t.icon}</div>
            <div className="target-info">
              <div className="target-label">{t.label}</div>
              <div className="target-current">{t.current || '—'} <span className="target-unit">{t.unit}</span></div>
              <div className="target-goal">Target: {t.target}</div>
            </div>
            <div className={`target-status-badge ${t.status}`}>
              {t.status === 'on-target' ? '✓ On Target' : t.status === 'warning' ? '⚠️ Monitor' : '× Off Target'}
            </div>
          </div>
        ))}
      </div>

      {/* BP Trend */}
      {condition === 'Hypertension' && vitals.filter(v => v.type === 'bp').length > 1 && (
        <div style={{ marginTop: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 1 }}>7-Day BP Trend</div>
          <div className="bp-sparkline-row">
            {vitals.filter(v => v.type === 'bp').slice(0, 7).reverse().map((v, i) => {
              const pct = Math.min(100, Math.max(5, ((v.systolic! - 80) / 80) * 100));
              const cat = bpCat(v.systolic!, v.diastolic!);
              return (
                <div key={i} className="spark-col" title={`${v.systolic}/${v.diastolic} — ${cat.label}\n${fmtShort(v.recordedAt)}`}>
                  <div className="spark-bar-outer">
                    <div className="spark-bar-inner" style={{ height: `${pct}%`, background: cat.color }} />
                  </div>
                  <div className="spark-date">{fmtShort(v.recordedAt)}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// LABS & IMAGING PANEL
// ═══════════════════════════════════════════════════════════════════════════
function LabsPanel({ patientId }: { patientId: string }) {
  const [labs, setLabs] = useState<LabResult[]>([]);
  const [filter, setFilter] = useState<'all'|'abnormal'|'critical'>('all');

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'lab_results'), where('patientId', '==', patientId), orderBy('date', 'desc')),
      snap => setLabs(snap.docs.map(d => ({ id: d.id, ...d.data() } as LabResult)))
    );
    return () => unsub();
  }, [patientId]);

  const statusColor = { normal: 'var(--green)', abnormal: 'var(--amber)', critical: 'var(--red)' };
  const filtered = filter === 'all' ? labs : labs.filter(l => l.status === filter);

  return (
    <div className="panel">
      <div className="panel-hd">
        <div className="panel-title">🔬 Lab Results</div>
        <div style={{ display: 'flex', gap: 4 }}>
          {(['all','abnormal','critical'] as const).map(f => (
            <button key={f} className={`filter-pill ${filter === f ? 'filter-on' : ''}`} onClick={() => setFilter(f)} style={{ padding: '4px 10px', fontSize: 11 }}>
              {f}
            </button>
          ))}
        </div>
      </div>
      {filtered.length === 0 ? (
        <div className="empty-sm"><div style={{ fontSize: 28 }}>🔬</div><p>No lab results yet. They'll appear when ordered by your doctor.</p></div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {filtered.map(lab => (
            <div key={lab.id} className="lab-card" style={{ borderLeft: `3px solid ${statusColor[lab.status]}` }}>
              <div className="lab-card-hd">
                <div>
                  <div className="lab-name">{lab.testName}</div>
                  <div className="lab-meta">{fmtShort(lab.date)} · {lab.orderedBy ? `Dr. ${lab.orderedBy}` : ''}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div className="lab-result" style={{ color: statusColor[lab.status] }}>{lab.result} {lab.unit}</div>
                  <div className="lab-ref">{lab.referenceRange && `Ref: ${lab.referenceRange}`}</div>
                  <span className="lab-status" style={{ background: `${statusColor[lab.status]}20`, color: statusColor[lab.status] }}>{lab.status}</span>
                </div>
              </div>
              {lab.notes && <p style={{ fontSize: 12, color: 'var(--text2)', marginTop: 6, fontStyle: 'italic' }}>{lab.notes}</p>}
              {lab.reportUrl && <a href={lab.reportUrl} target="_blank" rel="noreferrer" className="lab-download">📄 Download Report</a>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MESSAGES PANEL (with doctor)
// ═══════════════════════════════════════════════════════════════════════════
function MessagesPanel({ patient, appointments }: { patient: Patient; appointments: Appointment[] }) {
  const [threads, setThreads] = useState<any[]>([]);
  const [activeThread, setActiveThread] = useState<string | null>(null);
  const [msgs, setMsgs] = useState<any[]>([]);
  const [input, setInput] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const [uploading, setUploading] = useState(false);

  // Get unique doctors from completed appointments
  const myDoctors = Array.from(new Map(
    appointments.filter(a => a.status === 'completed' || a.status === 'active')
      .map(a => [a.doctorId, { id: a.doctorId, name: a.doctorName }])
  ).values());

  useEffect(() => {
    if (!activeThread) return;
    const threadId = [patient.uid, activeThread].sort().join('_');
    const unsub = onSnapshot(
      query(collection(db, 'messages'), where('threadId', '==', threadId), orderBy('timestamp', 'asc')),
      snap => {
        setMsgs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        setTimeout(() => endRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
        // Mark as read
        snap.docs.forEach(d => { if (!d.data().read && d.data().senderId !== patient.uid) updateDoc(d.ref, { read: true }); });
      }
    );
    return () => unsub();
  }, [activeThread, patient.uid]);

  const sendMsg = async (text?: string, fileUrl?: string, fileType?: string, fileName?: string) => {
    if (!activeThread) return;
    const threadId = [patient.uid, activeThread].sort().join('_');
    await addDoc(collection(db, 'messages'), {
      threadId, text: text || '', fileUrl, fileType, fileName,
      senderId: patient.uid, senderName: patient.name, senderRole: 'patient',
      timestamp: serverTimestamp(), read: false,
      type: fileUrl ? (fileType?.startsWith('image/') ? 'image' : 'file') : 'text',
    });
    setInput('');
  };

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    setUploading(true);
    const sRef = storageRef(storage, `messages/${patient.uid}/${Date.now()}_${file.name}`);
    const task = uploadBytesResumable(sRef, file);
    task.on('state_changed', null, console.error, async () => {
      const url = await getDownloadURL(task.snapshot.ref);
      await sendMsg('', url, file.type, file.name);
      setUploading(false);
    });
  };

  const doctorName = myDoctors.find(d => d.id === activeThread)?.name;

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr', gap: 16, height: 520 }}>
      {/* Thread list */}
      <div className="panel" style={{ overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <div className="panel-title" style={{ marginBottom: 12 }}>💬 Conversations</div>
        {myDoctors.length === 0 ? (
          <div className="empty-sm" style={{ padding: '20px 0' }}>
            <div style={{ fontSize: 24 }}>💬</div>
            <p style={{ fontSize: 12 }}>Messages appear after consultations</p>
          </div>
        ) : (
          <div style={{ overflowY: 'auto', flex: 1 }}>
            {myDoctors.map(d => (
              <button key={d.id} className={`msg-thread-btn ${activeThread === d.id ? 'msg-thread-on' : ''}`} onClick={() => setActiveThread(d.id)}>
                <div className="msg-thread-ava">{(d.name || 'D')[0]}</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 13 }}>Dr. {d.name}</div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Chat area */}
      <div className="panel" style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {!activeThread ? (
          <div className="empty-sm" style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ fontSize: 40, marginBottom: 10 }}>💬</div>
            <p>Select a conversation</p>
          </div>
        ) : (
          <>
            <div style={{ padding: '0 0 12px', borderBottom: '1px solid var(--border)', marginBottom: 12, fontWeight: 700, fontSize: 14 }}>
              Dr. {doctorName}
            </div>
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {msgs.map(m => (
                <div key={m.id} className={`msg-b ${m.senderId === patient.uid ? 'msg-b-mine' : 'msg-b-theirs'}`}>
                  <div className="msg-who">{m.senderRole === 'doctor' ? `🩺 Dr. ${m.senderName}` : 'You'}</div>
                  {m.type === 'text' && <span>{m.text}</span>}
                  {m.type === 'image' && <img src={m.fileUrl} alt={m.fileName} style={{ maxWidth: '100%', borderRadius: 8, marginTop: 4 }} />}
                  {m.type === 'file' && <a href={m.fileUrl} target="_blank" rel="noreferrer" className="msg-file-link">📎 {m.fileName}</a>}
                </div>
              ))}
              <div ref={endRef} />
            </div>
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 10, display: 'flex', gap: 6, marginTop: 10 }}>
              <button className="attach-btn-sm" onClick={() => fileRef.current?.click()} disabled={uploading} title="Attach file">
                {uploading ? '⏳' : '📎'}
              </button>
              <input className="msg-inp" value={input} onChange={e => setInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendMsg(input)}
                placeholder="Type a message…" style={{ flex: 1 }} />
              <button className="msg-send-btn" onClick={() => sendMsg(input)}>↑</button>
              <input ref={fileRef} type="file" style={{ display: 'none' }} onChange={handleFile} accept="image/*,.pdf,.doc,.docx" />
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EDUCATION PANEL
// ═══════════════════════════════════════════════════════════════════════════
function EducationPanel({ patientId, condition }: { patientId: string; condition?: string }) {
  const [items, setItems] = useState<Education[]>([]);

  useEffect(() => {
    const q = condition
      ? query(collection(db, 'education'), where('condition', 'in', [condition, 'General']))
      : query(collection(db, 'education'), where('condition', '==', 'General'));
    const unsub = onSnapshot(q, snap => setItems(snap.docs.map(d => ({ id: d.id, ...d.data() } as Education))));
    return () => unsub();
  }, [patientId, condition]);

  return (
    <div className="panel">
      <div className="panel-hd">
        <div className="panel-title">📚 Health Education</div>
        {condition && <span className="count-badge">{condition}</span>}
      </div>
      {items.length === 0 ? (
        <div className="empty-sm"><div style={{ fontSize: 28 }}>📚</div><p>Personalized articles will appear based on your condition.</p></div>
      ) : (
        <div className="edu-grid">
          {items.map(e => (
            <a key={e.id} href={e.url || '#'} target="_blank" rel="noreferrer" className="edu-card">
              {e.imageUrl && <img src={e.imageUrl} alt={e.title} className="edu-img" />}
              <div className="edu-body">
                <span className="edu-type">{e.type === 'video' ? '🎥' : '📄'} {e.type}</span>
                <div className="edu-title">{e.title}</div>
                <p className="edu-summary">{e.summary}</p>
                {e.readTime && <div className="edu-time">⏱ {e.readTime}</div>}
              </div>
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
export default function PatientDashboard() {
  const router = useRouter();
  const [authDone, setAuthDone] = useState(false);
  const [patient, setPatient] = useState<Patient | null>(null);
  const [services, setServices] = useState<Service[]>([]);
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [vitals, setVitals] = useState<VitalReading[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [activeTab, setActiveTab] = useState<string>('overview');
  const [bookSvc, setBookSvc] = useState<Service | null>(null);
  const [profileSvc, setProfileSvc] = useState<Service | null>(null);
  const [showLogVital, setShowLogVital] = useState(false);
  const [showTriage, setShowTriage] = useState(false);
  const [showSmartcard, setShowSmartcard] = useState(false);
  const [showEmergency, setShowEmergency] = useState(false);
  const [search, setSearch] = useState('');
  const [specialtyFilter, setSpecialtyFilter] = useState('All');
  const [triageDone, setTriageDone] = useState(false);
  const [triageSpecialty, setTriageSpecialty] = useState('All');
  const [joining, setJoining] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // ── Auth ──────────────────────────────────────────────────────────────
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async user => {
      if (!user) { router.replace('/login'); return; }
      const snap = await getDoc(doc(db, 'users', user.uid));
      const data = snap.data() || {};
      if (data.role === 'doctor') { router.replace('/dashboard/doctor'); return; }
      setPatient({
        uid: user.uid, name: data.name || user.displayName || 'Patient',
        email: data.email || user.email || '', phone: data.phone, age: data.age,
        gender: data.gender, bloodGroup: data.bloodGroup, condition: data.condition,
        universalId: data.universalId || `AMX-${user.uid.slice(0, 8).toUpperCase()}`,
        allergies: data.allergies || [], emergencyContact: data.emergencyContact,
        photoUrl: data.photoUrl, address: data.address, dateOfBirth: data.dateOfBirth,
        occupation: data.occupation, nextOfKin: data.nextOfKin,
        insuranceProvider: data.insuranceProvider, insuranceNumber: data.insuranceNumber,
      });
      setAuthDone(true);
    });
    return () => unsub();
  }, [router]);

  // ── Firestore listeners ───────────────────────────────────────────────
  useEffect(() => {
    const unsub = onSnapshot(query(collection(db, 'services'), where('isAvailable', '==', true)), snap =>
      setServices(snap.docs.map(d => ({ id: d.id, ...d.data() } as Service))));
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!patient) return;
    const unsub = onSnapshot(
      query(collection(db, 'appointments'), where('patientId', '==', patient.uid), orderBy('date', 'desc')),
      async snap => {
        const appts = await Promise.all(snap.docs.map(async d => {
          const appt = { id: d.id, ...d.data() } as Appointment;
          if (appt.consultationId) {
            try {
              const cs = await getDoc(doc(db, 'consultations', appt.consultationId));
              if (cs.exists()) {
                const cdata = cs.data();
                appt.prescriptions = cdata.prescriptions || [];
                appt.notes = cdata.notes || '';
              }
            } catch {}
          }
          return appt;
        }));
        setAppointments(appts);
      }
    );
    return () => unsub();
  }, [patient]);

  useEffect(() => {
    if (!patient) return;
    const unsub = onSnapshot(
      query(collection(db, 'vitals'), where('patientId', '==', patient.uid), orderBy('recordedAt', 'desc')),
      snap => setVitals(snap.docs.map(d => ({ id: d.id, ...d.data() } as VitalReading)))
    );
    return () => unsub();
  }, [patient]);

  useEffect(() => {
    if (!patient) return;
    const unsub = onSnapshot(
      query(collection(db, 'alerts'), where('patientId', '==', patient.uid), orderBy('createdAt', 'desc')),
      snap => setAlerts(snap.docs.map(d => ({ id: d.id, ...d.data() } as Alert)))
    );
    return () => unsub();
  }, [patient]);

  // ── Derived data ──────────────────────────────────────────────────────
  const activeAppts = appointments.filter(a => a.status === 'active');
  const upcomingAppts = appointments.filter(a => a.status === 'booked');
  const nextAppt = upcomingAppts[0];
  const countdown = useCountdown(nextAppt?.scheduledDate || nextAppt?.date);
  const unreadAlerts = alerts.filter(a => !a.read).length;
  const allPrescriptions = appointments.flatMap(a => (a.prescriptions || []).map(rx => ({ ...rx, apptId: a.id, doctorName: a.doctorName })));
  const specialties = ['All', ...Array.from(new Set(services.map(s => s.specialty)))];
  const clinics = ['All', ...Array.from(new Set(services.map(s => s.clinic)))];
  const [clinicFilter, setClinicFilter] = useState('All');

  const filteredSvcs = services.filter(s => {
    const q = search.toLowerCase();
    const matchQ = !q || `${s.specialty} ${s.doctorName} ${s.clinic} ${s.location || ''}`.toLowerCase().includes(q);
    const matchSp = specialtyFilter === 'All' || s.specialty === specialtyFilter;
    const matchCl = clinicFilter === 'All' || s.clinic === clinicFilter;
    const matchTriage = !triageDone || triageSpecialty === 'All' || s.specialty.toLowerCase().includes(triageSpecialty.toLowerCase());
    return matchQ && matchSp && matchCl && matchTriage;
  });

  // ── Join consultation ──────────────────────────────────────────────────
  const joinConsultation = async (appt: Appointment) => {
    setJoining(appt.id);
    try {
      if (appt.consultationId) { router.push(`/consultation/${appt.consultationId}`); return; }
      const q = query(collection(db, 'consultations'), where('appointmentId', '==', appt.id));
      const qs = await getDocs(q);
      if (!qs.empty) { router.push(`/consultation/${qs.docs[0].id}`); }
      else { alert('Consultation room not ready. Please wait for the doctor.'); }
    } catch { alert('Could not join. Please try again.'); }
    setJoining(null);
  };

  // ── Tabs ──────────────────────────────────────────────────────────────
  const tabs = [
    { id: 'overview', icon: '🏠', label: 'Overview' },
    { id: 'disease', icon: '🎯', label: 'My Health' },
    { id: 'discover', icon: '🔍', label: 'Find Doctors' },
    { id: 'vitals', icon: '📊', label: 'Vitals' },
    { id: 'appointments', icon: '📅', label: 'Appointments' },
    { id: 'prescriptions', icon: '💊', label: 'Prescriptions' },
    { id: 'labs', icon: '🔬', label: 'Labs' },
    { id: 'history', icon: '📋', label: 'History' },
    { id: 'messages', icon: '💬', label: 'Messages', badge: alerts.filter(a => !a.read && a.type === 'message').length },
    { id: 'education', icon: '📚', label: 'Education' },
    { id: 'payments', icon: '💳', label: 'Payments' },
    { id: 'settings', icon: '⚙️', label: 'Settings' },
  ];

  // ── Loading state ──────────────────────────────────────────────────────
  if (!authDone || !patient) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0b0f1a', fontFamily: "'DM Sans', sans-serif" }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: 48, height: 48, border: '3px solid #1e2535', borderTopColor: '#00e5cc', borderRadius: '50%', animation: 'spin .7s linear infinite', margin: '0 auto 16px' }} />
          <p style={{ color: '#64748b', fontSize: 14 }}>Loading your health profile…</p>
          <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
        </div>
      </div>
    );
  }

  const latestBP = vitals.find(v => v.type === 'bp');
  const bpInfo = latestBP ? bpCat(latestBP.systolic!, latestBP.diastolic!) : null;

  // ══════════════════════════════════════════════════════════════════════
  // RENDER
  // ══════════════════════════════════════════════════════════════════════
  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Syne:wght@400;500;600;700;800;900&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;0,9..40,800;1,9..40,400&family=JetBrains+Mono:wght@400;500;700&display=swap');

        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
          --bg: #0b0f1a;
          --surface: #111827;
          --surface2: #1a2338;
          --surface3: #1e2a3d;
          --border: #243047;
          --border2: #2d3f58;
          --text: #e8edf5;
          --text2: #8b9bbf;
          --muted: #546382;
          --accent: #00e5cc;
          --accent2: #7c5af5;
          --accent3: #3b82f6;
          --green: #00d68f;
          --amber: #ffb020;
          --red: #ff4560;
          --font: 'DM Sans', sans-serif;
          --font-display: 'Syne', sans-serif;
          --mono: 'JetBrains Mono', monospace;
          --r: 14px;
          --r-sm: 9px;
          --r-lg: 20px;
          --shadow: 0 1px 4px rgba(0,0,0,0.3), 0 1px 2px rgba(0,0,0,0.2);
          --shadow-md: 0 4px 20px rgba(0,0,0,0.4);
          --shadow-lg: 0 16px 48px rgba(0,0,0,0.5);
        }

        html, body { height: 100%; background: var(--bg); color: var(--text); font-family: var(--font); -webkit-font-smoothing: antialiased; }
        @keyframes spin { to { transform: rotate(360deg); } }
        @keyframes fadeUp { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: none; } }
        @keyframes pulse { 0%,100%{opacity:1}50%{opacity:.5} }
        @keyframes slideIn { from { opacity: 0; transform: translateX(-16px); } to { opacity: 1; transform: none; } }
        ::-webkit-scrollbar { width: 4px; height: 4px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #2d3f58; border-radius: 99px; }

        /* ── LAYOUT ──────────────────────────────────────────────────────── */
        .shell { display: flex; min-height: 100vh; }
        .sidebar {
          width: 228px; background: var(--surface); border-right: 1px solid var(--border);
          display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh;
          flex-shrink: 0; z-index: 30; overflow: hidden;
        }
        .main { flex: 1; overflow-y: auto; min-height: 100vh; display: flex; flex-direction: column; }

        /* ── SIDEBAR ─────────────────────────────────────────────────────── */
        .sb-brand { padding: 20px 18px 14px; border-bottom: 1px solid var(--border); }
        .sb-logo { display: flex; align-items: center; gap: 9px; }
        .sb-logo-glyph {
          width: 34px; height: 34px; border-radius: 9px;
          background: linear-gradient(135deg, #00e5cc, #7c5af5);
          display: flex; align-items: center; justify-content: center;
          font-size: 17px; box-shadow: 0 4px 14px rgba(0,229,204,0.3);
        }
        .sb-logo-name { font-family: var(--font-display); font-size: 17px; font-weight: 800; color: var(--text); letter-spacing: -0.3px; }
        .sb-logo-sub { font-size: 9px; color: var(--accent); font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; }

        .sb-profile { padding: 14px 18px; border-bottom: 1px solid var(--border); }
        .sb-ava {
          width: 40px; height: 40px; border-radius: 10px;
          background: linear-gradient(135deg, #7c5af5, #00e5cc);
          display: flex; align-items: center; justify-content: center;
          font-weight: 800; font-size: 16px; color: white; overflow: hidden;
        }
        .sb-pname { font-weight: 700; font-size: 13px; margin-top: 8px; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .sb-pid { font-size: 10px; color: var(--muted); font-family: var(--mono); margin-top: 2px; }
        .sb-cond { display: inline-flex; align-items: center; gap: 4px; margin-top: 6px; font-size: 10px; font-weight: 700; padding: 3px 8px; border-radius: 99px; background: rgba(0,229,204,.1); color: var(--accent); }

        .sb-nav { flex: 1; overflow-y: auto; padding: 10px 8px; display: flex; flex-direction: column; gap: 1px; }
        .sb-item {
          display: flex; align-items: center; gap: 9px; padding: 9px 11px; border-radius: var(--r-sm);
          border: none; background: transparent; color: var(--text2); font-size: 12.5px; font-weight: 500;
          cursor: pointer; font-family: var(--font); width: 100%; text-align: left; transition: all 0.15s;
          white-space: nowrap;
        }
        .sb-item:hover { background: var(--surface2); color: var(--text); }
        .sb-item.active { background: rgba(0,229,204,.1); color: var(--accent); font-weight: 700; }
        .sb-item-icon { font-size: 15px; flex-shrink: 0; width: 20px; text-align: center; }
        .sb-badge { margin-left: auto; background: var(--red); color: white; border-radius: 99px; min-width: 18px; height: 18px; font-size: 9px; display: inline-flex; align-items: center; justify-content: center; padding: 0 4px; }

        .sb-footer { padding: 10px 8px; border-top: 1px solid var(--border); }
        .sb-signout { display: flex; align-items: center; gap: 8px; width: 100%; padding: 9px 11px; background: transparent; border: 1px solid var(--border); border-radius: var(--r-sm); color: var(--muted); font-size: 12.5px; font-weight: 500; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .sb-signout:hover { border-color: var(--red); color: var(--red); background: rgba(255,69,96,.08); }

        /* ── TOP HEADER ──────────────────────────────────────────────────── */
        .top-hd {
          background: var(--surface); border-bottom: 1px solid var(--border);
          padding: 12px 24px; display: flex; justify-content: space-between; align-items: center;
          position: sticky; top: 0; z-index: 20; backdrop-filter: blur(12px);
        }
        .th-left { display: flex; flex-direction: column; }
        .th-greeting { font-size: 11px; color: var(--muted); font-weight: 500; }
        .th-name { font-family: var(--font-display); font-size: 18px; font-weight: 800; letter-spacing: -0.3px; }
        .th-actions { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
        .th-btn {
          display: flex; align-items: center; gap: 5px; padding: 7px 13px; border-radius: var(--r-sm);
          border: 1px solid var(--border2); background: var(--surface2); color: var(--text2);
          font-size: 11.5px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all 0.15s;
        }
        .th-btn:hover { border-color: var(--accent); color: var(--accent); background: rgba(0,229,204,.06); }
        .th-btn-accent { background: linear-gradient(135deg, #7c5af5, #00e5cc); color: #000; border: none; font-weight: 700; box-shadow: 0 4px 14px rgba(124,90,245,0.35); }
        .th-btn-accent:hover { opacity: 0.9; color: #000; }

        /* ── CONTENT ─────────────────────────────────────────────────────── */
        .content { padding: 22px 24px; flex: 1; animation: fadeUp 0.25s ease; }

        /* ── LIVE BANNER ─────────────────────────────────────────────────── */
        .live-banner {
          background: linear-gradient(90deg, rgba(0,214,143,.08), rgba(0,214,143,.04));
          border: 1px solid rgba(0,214,143,.25); border-radius: var(--r); padding: 13px 18px;
          margin-bottom: 18px; display: flex; justify-content: space-between; align-items: center; gap: 12px;
        }
        .live-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--green); animation: pulse 1.5s infinite; }
        .btn-join-live { background: var(--green); color: #000; border: none; border-radius: 10px; padding: 9px 18px; font-weight: 700; font-size: 13px; cursor: pointer; font-family: var(--font); }
        .btn-join-live:hover { background: #00f0a4; }
        .btn-join-live:disabled { opacity: 0.6; cursor: not-allowed; }

        /* ── HERO ────────────────────────────────────────────────────────── */
        .hero-row { display: grid; grid-template-columns: 1fr auto; gap: 14px; margin-bottom: 18px; }
        .hero-card {
          background: linear-gradient(135deg, #0d1f3c 0%, #162848 40%, #0f2034 100%);
          border: 1px solid var(--border2); border-radius: var(--r-lg); padding: 24px 26px;
          position: relative; overflow: hidden;
        }
        .hero-card::before { content: ''; position: absolute; top: -60px; right: -60px; width: 220px; height: 220px; border-radius: 50%; background: radial-gradient(circle, rgba(0,229,204,.12) 0%, transparent 70%); pointer-events: none; }
        .hero-card::after { content: ''; position: absolute; bottom: -80px; left: 20px; width: 180px; height: 180px; border-radius: 50%; background: radial-gradient(circle, rgba(124,90,245,.1) 0%, transparent 70%); pointer-events: none; }
        .hero-greet { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.8px; color: var(--accent); margin-bottom: 4px; }
        .hero-name { font-family: var(--font-display); font-size: 22px; font-weight: 900; letter-spacing: -0.3px; color: var(--text); }
        .hero-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
        .hero-chip { background: rgba(255,255,255,.07); backdrop-filter: blur(8px); border: 1px solid rgba(255,255,255,.1); border-radius: 99px; padding: 3px 10px; font-size: 11px; font-weight: 600; color: var(--text2); }
        .hero-tip { margin-top: 14px; padding: 10px 14px; background: rgba(0,229,204,.08); border: 1px solid rgba(0,229,204,.15); border-radius: 10px; font-size: 12.5px; color: var(--text2); line-height: 1.6; }

        .next-appt-card {
          background: var(--surface); border: 1px solid var(--border2); border-radius: var(--r-lg);
          padding: 18px; min-width: 190px; display: flex; flex-direction: column; gap: 5px;
        }
        .na-label { font-size: 9px; color: var(--accent); font-weight: 700; text-transform: uppercase; letter-spacing: 1.2px; }
        .na-count { font-family: var(--mono); font-size: 26px; font-weight: 700; color: var(--text); }
        .na-badge { display: inline-flex; background: rgba(0,229,204,.12); color: var(--accent); border-radius: 99px; padding: 3px 10px; font-size: 11px; font-weight: 700; width: fit-content; }
        .na-doctor { font-size: 12px; color: var(--text2); font-weight: 600; }
        .na-date { font-size: 10px; color: var(--muted); font-family: var(--mono); }

        /* ── STATS GRID ──────────────────────────────────────────────────── */
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-bottom: 20px; }
        .stat-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r); padding: 14px 16px; display: flex; align-items: center; gap: 12px; transition: all 0.2s; }
        .stat-card:hover { border-color: var(--accent); }
        .stat-icon { font-size: 26px; flex-shrink: 0; }
        .stat-val { font-family: var(--mono); font-size: 20px; font-weight: 700; }
        .stat-lbl { font-size: 10px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }

        /* ── PANELS ──────────────────────────────────────────────────────── */
        .panel { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r); padding: 18px 20px; }
        .panel-hd { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }
        .panel-title { font-size: 13.5px; font-weight: 700; color: var(--text); }
        .count-badge { background: rgba(0,229,204,.1); color: var(--accent); border-radius: 99px; font-size: 10px; font-weight: 700; padding: 2px 8px; }
        .empty-sm { text-align: center; padding: 28px 0; color: var(--muted); font-size: 13px; }
        .btn-sm-accent { background: rgba(0,229,204,.12); color: var(--accent); border: 1px solid rgba(0,229,204,.2); border-radius: 7px; padding: 6px 12px; font-size: 11px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-sm-accent:hover { background: rgba(0,229,204,.2); }

        /* ── OVERVIEW GRIDS ──────────────────────────────────────────────── */
        .overview-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
        .full-width { grid-column: 1 / -1; }

        /* ── VITALS ──────────────────────────────────────────────────────── */
        .vital-main { border: 1.5px solid var(--border2); border-radius: 12px; padding: 14px; margin-bottom: 12px; }
        .vital-main-val { font-family: var(--mono); font-size: 26px; font-weight: 700; }
        .vital-badge { display: inline-flex; padding: 2px 9px; border-radius: 99px; font-size: 11px; font-weight: 700; margin-top: 4px; }
        .vitals-mini { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
        .vital-mini { background: var(--surface2); border-radius: 10px; padding: 10px 8px; text-align: center; display: flex; flex-direction: column; align-items: center; gap: 3px; }
        .vital-mini-val { font-family: var(--mono); font-size: 15px; font-weight: 700; }

        /* ── BP SPARKLINE ─────────────────────────────────────────────────── */
        .bp-sparkline-row { display: flex; gap: 8px; align-items: flex-end; height: 56px; }
        .spark-col { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 4px; height: 100%; }
        .spark-bar-outer { flex: 1; width: 100%; background: var(--surface3); border-radius: 4px; display: flex; align-items: flex-end; overflow: hidden; }
        .spark-bar-inner { width: 100%; border-radius: 4px; transition: height 0.5s ease; }
        .spark-date { font-size: 8px; color: var(--muted); font-family: var(--mono); }

        /* ── DISEASE PANEL ───────────────────────────────────────────────── */
        .disease-panel {
          background: linear-gradient(135deg, #0d1a2e, #0f2035);
          border: 1px solid rgba(0,229,204,.2); border-radius: var(--r-lg);
          padding: 20px 22px; margin-bottom: 18px;
        }
        .disease-panel-hd { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 8px; }
        .disease-icon { font-size: 24px; }
        .disease-title { font-family: var(--font-display); font-size: 16px; font-weight: 800; color: var(--text); }
        .disease-sub { font-size: 11px; color: var(--muted); margin-top: 2px; }
        .disease-alert { background: rgba(255,69,96,.1); border: 1px solid rgba(255,69,96,.25); border-radius: 9px; padding: 10px 14px; font-size: 12px; color: var(--text2); display: flex; justify-content: space-between; align-items: center; gap: 8px; }
        .dismiss-btn { background: none; border: none; color: var(--muted); cursor: pointer; font-size: 12px; flex-shrink: 0; }
        .targets-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
        .target-card { background: var(--surface2); border: 1.5px solid var(--border2); border-radius: 12px; padding: 14px 16px; display: flex; align-items: center; gap: 12px; }
        .target-card.target-on-target { border-color: rgba(0,214,143,.3); background: rgba(0,214,143,.05); }
        .target-card.target-off-target { border-color: rgba(255,69,96,.3); background: rgba(255,69,96,.05); }
        .target-card.target-warning { border-color: rgba(255,176,32,.3); background: rgba(255,176,32,.05); }
        .target-icon { font-size: 24px; flex-shrink: 0; }
        .target-label { font-size: 11px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
        .target-current { font-family: var(--mono); font-size: 20px; font-weight: 700; color: var(--text); }
        .target-unit { font-size: 11px; color: var(--muted); font-weight: 400; }
        .target-goal { font-size: 11px; color: var(--text2); margin-top: 2px; }
        .target-status-badge { margin-left: auto; flex-shrink: 0; font-size: 10px; font-weight: 700; padding: 3px 9px; border-radius: 99px; }
        .target-status-badge.on-target { background: rgba(0,214,143,.15); color: var(--green); }
        .target-status-badge.off-target { background: rgba(255,69,96,.15); color: var(--red); }
        .target-status-badge.warning { background: rgba(255,176,32,.15); color: var(--amber); }

        /* ── PRESCRIPTIONS ───────────────────────────────────────────────── */
        .rx-card { background: var(--surface2); border: 1px solid var(--border); border-radius: 12px; padding: 14px 16px; }
        .rx-card-hd { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px; }
        .rx-card-name { font-weight: 700; font-size: 14px; color: var(--text); }
        .rx-card-doc { font-size: 11px; color: var(--muted); }
        .rx-card-meta { display: flex; gap: 8px; flex-wrap: wrap; font-size: 12px; color: var(--text2); }
        .rx-card-instructions { font-size: 12px; color: var(--text2); margin-top: 6px; font-style: italic; border-top: 1px solid var(--border); padding-top: 6px; }
        .cal-row { display: flex; gap: 4px; margin-top: 10px; }
        .cal-day { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 5px 2px; border-radius: 8px; background: var(--surface3); border: 1px solid var(--border); cursor: pointer; transition: all .2s; }
        .cal-day:hover { border-color: var(--accent); }
        .cal-day.cal-taken { background: rgba(0,214,143,.15); border-color: rgba(0,214,143,.4); }
        .cal-day.cal-today { border-color: var(--accent); }
        .cal-dn { font-size: 9px; color: var(--muted); font-weight: 700; text-transform: uppercase; }
        .cal-dd { font-size: 12px; font-weight: 700; color: var(--text); font-family: var(--mono); }
        .cal-check { font-size: 10px; color: var(--green); }

        /* ── DISCOVER ────────────────────────────────────────────────────── */
        .triage-prompt { background: linear-gradient(135deg, rgba(124,90,245,.08), rgba(0,229,204,.04)); border: 1px solid rgba(124,90,245,.2); border-radius: var(--r); padding: 16px 20px; margin-bottom: 18px; display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
        .triage-done { background: rgba(0,214,143,.06); border: 1px solid rgba(0,214,143,.2); border-radius: var(--r); padding: 10px 16px; margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; }
        .discover-controls { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
        .search-wrap { position: relative; flex: 1 1 220px; }
        .search-icon { position: absolute; left: 11px; top: 50%; transform: translateY(-50%); font-size: 14px; pointer-events: none; }
        .discover-search { width: 100%; padding: 9px 13px 9px 36px; background: var(--surface2); border: 1px solid var(--border2); border-radius: var(--r-sm); color: var(--text); font-size: 13px; font-family: var(--font); outline: none; transition: border-color .15s; }
        .discover-search:focus { border-color: var(--accent); }
        .pills { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 14px; }
        .pill { padding: 5px 12px; border-radius: 99px; border: 1px solid var(--border2); background: var(--surface2); color: var(--text2); font-size: 11px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .pill.on { background: rgba(0,229,204,.12); border-color: rgba(0,229,204,.3); color: var(--accent); }
        .pill:not(.on):hover { border-color: var(--accent); color: var(--accent); }
        .svc-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 14px; }
        .svc-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 0; overflow: hidden; display: flex; flex-direction: column; transition: all .2s; cursor: pointer; }
        .svc-card:hover { border-color: rgba(0,229,204,.3); transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0,0,0,.4); }
        .svc-card-banner { height: 4px; background: linear-gradient(90deg, var(--accent), var(--accent2)); }
        .svc-card-body { padding: 18px; display: flex; flex-direction: column; gap: 11px; flex: 1; }
        .svc-card-hd { display: flex; justify-content: space-between; align-items: flex-start; }
        .svc-spec { font-family: var(--font-display); font-weight: 800; font-size: 15px; color: var(--text); }
        .svc-price { font-family: var(--mono); font-size: 16px; font-weight: 700; color: var(--accent); }
        .svc-doc-row { display: flex; align-items: center; gap: 9px; }
        .svc-doc-ava { width: 36px; height: 36px; border-radius: 9px; overflow: hidden; background: linear-gradient(135deg, #7c5af5, #00e5cc); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 14px; color: white; flex-shrink: 0; }
        .svc-doc-name { font-weight: 700; font-size: 13px; color: var(--text); }
        .svc-doc-clinic { font-size: 11px; color: var(--muted); }
        .svc-chips { display: flex; gap: 5px; flex-wrap: wrap; }
        .svc-chip { background: var(--surface2); color: var(--text2); border-radius: 99px; padding: 2px 9px; font-size: 10px; font-weight: 600; border: 1px solid var(--border2); }
        .svc-desc { font-size: 12px; color: var(--text2); line-height: 1.6; flex: 1; }
        .svc-card-footer { padding: 0 18px 18px; display: flex; gap: 8px; }
        .btn-view-profile { flex: 1; background: var(--surface2); border: 1px solid var(--border2); color: var(--text2); border-radius: 9px; padding: 9px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .btn-view-profile:hover { border-color: var(--accent); color: var(--accent); }
        .btn-book { flex: 1; background: linear-gradient(135deg, #7c5af5, #00e5cc); color: #000; border: none; border-radius: 9px; padding: 9px; font-size: 12px; font-weight: 800; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .btn-book:hover { opacity: .9; }

        /* ── DOCTOR DRAWER ───────────────────────────────────────────────── */
        .drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.7); z-index: 90; display: flex; justify-content: flex-end; backdrop-filter: blur(4px); }
        .drawer { background: var(--surface); width: min(520px, 100vw); height: 100vh; overflow-y: auto; display: flex; flex-direction: column; animation: slideIn .2s ease; position: relative; }
        .drawer-close { position: absolute; top: 14px; right: 14px; background: var(--surface2); border: none; color: var(--text2); width: 30px; height: 30px; border-radius: 8px; cursor: pointer; font-size: 13px; z-index: 2; transition: all .15s; }
        .drawer-close:hover { background: rgba(255,69,96,.12); color: var(--red); }
        .dr-profile-hero { padding: 28px 22px 22px; display: flex; flex-direction: column; gap: 14px; }
        .dr-profile-ava { width: 72px; height: 72px; border-radius: 50%; background: linear-gradient(135deg, #7c5af5, #00e5cc); display: flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 800; color: white; overflow: hidden; border: 3px solid rgba(0,229,204,.3); }
        .dr-profile-name { font-family: var(--font-display); font-size: 22px; font-weight: 900; color: var(--text); }
        .dr-profile-spec { font-size: 13px; color: var(--text2); margin-top: 3px; }
        .dr-profile-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
        .dr-chip { background: rgba(0,229,204,.1); color: var(--accent); border-radius: 99px; padding: 3px 10px; font-size: 11px; font-weight: 700; border: 1px solid rgba(0,229,204,.2); }
        .drawer-body { padding: 20px; flex: 1; display: flex; flex-direction: column; gap: 18px; }
        .dr-price-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
        .dr-price-box { background: var(--surface2); border: 1px solid var(--border); border-radius: 10px; padding: 12px; text-align: center; }
        .dr-price-label { font-size: 9px; color: var(--muted); font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; display: block; }
        .dr-price-val { font-family: var(--mono); font-size: 15px; font-weight: 700; color: var(--text); display: block; margin-top: 4px; }
        .dr-section { display: flex; flex-direction: column; gap: 8px; }
        .dr-section-title { font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); }
        .dr-section-body { font-size: 13px; color: var(--text2); line-height: 1.7; }
        .dr-dedication { background: rgba(124,90,245,.08); border: 1px solid rgba(124,90,245,.2); border-radius: 12px; padding: 14px; font-size: 13px; color: var(--text2); font-style: italic; line-height: 1.7; position: relative; }
        .dr-quote { font-size: 32px; color: var(--accent2); opacity: 0.4; position: absolute; top: 6px; left: 12px; font-family: Georgia, serif; line-height: 1; }
        .dr-qual-list { display: flex; flex-direction: column; gap: 5px; }
        .dr-qual-item { font-size: 12.5px; color: var(--text2); }
        .dr-tags { display: flex; flex-wrap: wrap; gap: 6px; }
        .dr-tag { background: var(--surface2); border: 1px solid var(--border2); color: var(--text2); border-radius: 99px; padding: 3px 10px; font-size: 11px; }
        .dr-info-grid { display: flex; flex-direction: column; gap: 10px; }
        .dr-info-item { display: flex; align-items: flex-start; gap: 10px; }
        .dr-info-icon { font-size: 18px; flex-shrink: 0; margin-top: 1px; }
        .dr-info-label { font-size: 9px; color: var(--muted); font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; display: block; }
        .dr-info-val { font-size: 13px; color: var(--text); display: block; margin-top: 2px; }
        .btn-book-full { background: linear-gradient(135deg, #7c5af5, #00e5cc); color: #000; border: none; border-radius: 12px; padding: 14px; font-size: 14px; font-weight: 800; cursor: pointer; font-family: var(--font); width: 100%; transition: all .15s; box-shadow: 0 4px 20px rgba(124,90,245,.35); }
        .btn-book-full:hover { opacity: .9; }

        /* ── APPOINTMENTS ────────────────────────────────────────────────── */
        .appt-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r); padding: 14px 18px; display: flex; justify-content: space-between; align-items: center; gap: 12px; transition: border-color .15s; }
        .appt-card:hover { border-color: var(--border2); }
        .appt-icon { width: 42px; height: 42px; border-radius: 11px; background: rgba(0,229,204,.1); display: flex; align-items: center; justify-content: center; font-size: 19px; flex-shrink: 0; }
        .appt-spec { font-weight: 700; font-size: 13.5px; color: var(--text); }
        .appt-dr { font-size: 12px; color: var(--text2); margin-top: 2px; }
        .appt-date { font-size: 11px; color: var(--muted); font-family: var(--mono); margin-top: 2px; }
        .appt-first-visit { display: inline-flex; background: rgba(255,176,32,.12); color: var(--amber); border-radius: 99px; padding: 1px 7px; font-size: 9px; font-weight: 700; margin-left: 6px; }
        .status-pill { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 99px; font-size: 10px; font-weight: 700; }
        .btn-join-sm { background: var(--green); color: #000; border: none; border-radius: 7px; padding: 7px 13px; font-size: 11px; font-weight: 700; cursor: pointer; font-family: var(--font); }
        .btn-records { background: transparent; border: 1px solid var(--border2); color: var(--text2); border-radius: 7px; padding: 6px 11px; font-size: 11px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .btn-records:hover { border-color: var(--accent); color: var(--accent); }

        /* ── LABS ────────────────────────────────────────────────────────── */
        .lab-card { background: var(--surface2); border: 1px solid var(--border); border-radius: 11px; padding: 13px 15px; }
        .lab-card-hd { display: flex; justify-content: space-between; align-items: flex-start; }
        .lab-name { font-weight: 700; font-size: 13px; color: var(--text); }
        .lab-meta { font-size: 11px; color: var(--muted); margin-top: 2px; }
        .lab-result { font-family: var(--mono); font-size: 15px; font-weight: 700; }
        .lab-ref { font-size: 10px; color: var(--muted); }
        .lab-status { display: inline-block; font-size: 10px; font-weight: 700; padding: 2px 7px; border-radius: 99px; margin-top: 3px; }
        .lab-download { display: inline-flex; align-items: center; gap: 4px; font-size: 11px; color: var(--accent); text-decoration: none; margin-top: 8px; }

        /* ── TIMELINE ────────────────────────────────────────────────────── */
        .filter-bar { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 14px; overflow-x: auto; padding-bottom: 4px; }
        .filter-pill { padding: 4px 11px; border-radius: 99px; border: 1px solid var(--border2); background: var(--surface2); color: var(--text2); font-size: 11px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; white-space: nowrap; }
        .filter-pill.filter-on { background: rgba(0,229,204,.1); border-color: rgba(0,229,204,.25); color: var(--accent); }
        .timeline { display: flex; flex-direction: column; gap: 0; }
        .timeline-entry { display: flex; gap: 14px; }
        .timeline-dot { width: 30px; height: 30px; border-radius: 50%; background: var(--surface2); border: 1px solid var(--border2); display: flex; align-items: center; justify-content: center; font-size: 13px; flex-shrink: 0; margin-top: 4px; position: relative; z-index: 1; }
        .timeline-entry:not(:last-child) .timeline-dot::after { content: ''; position: absolute; top: 30px; left: 50%; transform: translateX(-50%); width: 1px; height: calc(100% + 14px); background: var(--border); }
        .timeline-content { flex: 1; background: var(--surface2); border: 1px solid var(--border); border-radius: 11px; padding: 12px 14px; margin-bottom: 10px; cursor: pointer; transition: border-color .15s; }
        .timeline-content:hover { border-color: var(--border2); }
        .timeline-hd { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
        .timeline-section { font-weight: 700; font-size: 13px; color: var(--text); }
        .timeline-meta { font-size: 10px; color: var(--muted); margin-top: 2px; font-family: var(--mono); }
        .timeline-type-badge { font-size: 9px; font-weight: 700; padding: 2px 7px; border-radius: 99px; background: var(--surface3); color: var(--text2); text-transform: uppercase; flex-shrink: 0; }
        .timeline-body { margin-top: 10px; border-top: 1px solid var(--border); padding-top: 10px; }

        /* ── MESSAGES ────────────────────────────────────────────────────── */
        .msg-thread-btn { display: flex; align-items: center; gap: 9px; width: 100%; padding: 10px 8px; background: transparent; border: none; border-radius: 9px; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .msg-thread-btn:hover { background: var(--surface2); }
        .msg-thread-btn.msg-thread-on { background: rgba(0,229,204,.08); }
        .msg-thread-ava { width: 34px; height: 34px; border-radius: 9px; background: linear-gradient(135deg, #7c5af5, #00e5cc); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 13px; color: white; flex-shrink: 0; }
        .msg-b { padding: 8px 12px; border-radius: 11px; max-width: 88%; font-size: 13px; line-height: 1.5; }
        .msg-b-mine { background: #7c5af5; color: white; align-self: flex-end; border-bottom-right-radius: 3px; }
        .msg-b-theirs { background: var(--surface2); color: var(--text); align-self: flex-start; border: 1px solid var(--border); border-bottom-left-radius: 3px; }
        .msg-who { font-size: 9px; opacity: .7; margin-bottom: 3px; font-weight: 700; }
        .msg-file-link { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; color: var(--accent); text-decoration: none; margin-top: 4px; }
        .msg-inp { background: var(--surface2); border: 1px solid var(--border2); border-radius: 9px; padding: 9px 12px; color: var(--text); font-size: 13px; font-family: var(--font); outline: none; }
        .msg-inp:focus { border-color: var(--accent); }
        .msg-send-btn { background: var(--accent); border: none; color: #000; padding: 9px 14px; border-radius: 9px; font-weight: 800; cursor: pointer; font-size: 14px; }
        .attach-btn-sm { background: var(--surface2); border: 1px solid var(--border2); color: var(--text2); padding: 9px 12px; border-radius: 9px; cursor: pointer; transition: all .15s; }
        .attach-btn-sm:hover { border-color: var(--accent); color: var(--accent); }

        /* ── PAYMENTS ────────────────────────────────────────────────────── */
        .pay-pending-card { background: rgba(255,176,32,.05); border: 1px solid rgba(255,176,32,.2); border-radius: 11px; padding: 13px 15px; display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 8px; }
        .pay-history-card { background: var(--surface2); border: 1px solid var(--border); border-radius: 11px; padding: 12px 14px; display: flex; justify-content: space-between; align-items: center; gap: 12px; }
        .retry-btn { display: block; margin-top: 6px; background: none; border: 1px solid var(--amber); color: var(--amber); border-radius: 6px; padding: 4px 10px; font-size: 11px; font-weight: 700; cursor: pointer; font-family: var(--font); }

        /* ── EDUCATION ───────────────────────────────────────────────────── */
        .edu-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 12px; }
        .edu-card { background: var(--surface2); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; text-decoration: none; display: flex; flex-direction: column; transition: all .2s; }
        .edu-card:hover { border-color: var(--border2); transform: translateY(-2px); }
        .edu-img { width: 100%; height: 120px; object-fit: cover; }
        .edu-body { padding: 13px; display: flex; flex-direction: column; gap: 5px; }
        .edu-type { font-size: 10px; color: var(--muted); font-weight: 700; text-transform: uppercase; }
        .edu-title { font-weight: 700; font-size: 13px; color: var(--text); line-height: 1.4; }
        .edu-summary { font-size: 12px; color: var(--text2); line-height: 1.6; }
        .edu-time { font-size: 10px; color: var(--muted); }

        /* ── SETTINGS ────────────────────────────────────────────────────── */
        .settings-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r); padding: 20px; }
        .settings-card-title { font-size: 14px; font-weight: 700; color: var(--text); margin-bottom: 16px; }
        .settings-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
        .settings-avatar { width: 60px; height: 60px; border-radius: 50%; background: linear-gradient(135deg, #7c5af5, #00e5cc); display: flex; align-items: center; justify-content: center; font-size: 22px; font-weight: 800; color: white; flex-shrink: 0; overflow: hidden; }
        .msg-banner { padding: 10px 14px; border-radius: 9px; font-size: 12px; font-weight: 600; }
        .msg-ok { background: rgba(0,214,143,.1); color: var(--green); border: 1px solid rgba(0,214,143,.2); }
        .msg-err { background: rgba(255,69,96,.1); color: var(--red); border: 1px solid rgba(255,69,96,.2); }

        /* ── SMARTCARD ───────────────────────────────────────────────────── */
        .smartcard { background: linear-gradient(135deg, #0d1a2e, #162848); border: 1px solid var(--border2); border-radius: 16px; padding: 20px; }
        .sc-top { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
        .sc-avatar { width: 48px; height: 48px; border-radius: 12px; background: linear-gradient(135deg, #7c5af5, #00e5cc); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px; color: white; overflow: hidden; }
        .sc-name { font-weight: 800; font-size: 15px; color: var(--text); }
        .sc-id { font-size: 10px; color: var(--muted); font-family: var(--mono); margin-top: 2px; }
        .sc-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; margin-bottom: 10px; }
        .sc-item { background: rgba(255,255,255,.04); border-radius: 7px; padding: 7px 9px; }
        .sc-key { font-size: 9px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; font-weight: 700; display: block; }
        .sc-val { font-size: 13px; font-weight: 700; color: var(--text); display: block; margin-top: 2px; }
        .sc-allergy { background: rgba(255,69,96,.12); border: 1px solid rgba(255,69,96,.3); border-radius: 8px; padding: 7px 10px; font-size: 11px; font-weight: 700; color: #fca5a5; margin-top: 5px; }
        .sc-emergency { background: rgba(255,176,32,.12); border: 1px solid rgba(255,176,32,.3); border-radius: 8px; padding: 7px 10px; font-size: 11px; font-weight: 700; color: #fcd34d; margin-top: 5px; }

        /* ── MODALS ──────────────────────────────────────────────────────── */
        .overlay { position: fixed; inset: 0; background: rgba(0,0,0,.75); z-index: 100; display: flex; align-items: center; justify-content: center; padding: 16px; backdrop-filter: blur(8px); }
        .modal-box { background: var(--surface); border: 1px solid var(--border2); border-radius: 20px; width: 100%; max-width: 480px; max-height: 92vh; overflow-y: auto; box-shadow: var(--shadow-lg); animation: fadeUp .2s ease; }
        .modal-hd { padding: 20px 20px 0; display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
        .modal-ht { font-family: var(--font-display); font-size: 18px; font-weight: 800; color: var(--text); }
        .modal-hs { font-size: 12px; color: var(--muted); margin-top: 3px; }
        .modal-close { background: var(--surface2); border: none; color: var(--text2); width: 28px; height: 28px; border-radius: 7px; cursor: pointer; font-size: 13px; flex-shrink: 0; transition: all .15s; }
        .modal-close:hover { background: rgba(255,69,96,.12); color: var(--red); }
        .modal-body { padding: 0 20px 20px; display: flex; flex-direction: column; gap: 14px; }
        .steps-bar { padding: 0 20px 14px; display: flex; align-items: center; gap: 2px; }
        .step-wrap { display: flex; align-items: center; gap: 4px; }
        .step-num { width: 22px; height: 22px; border-radius: 50%; background: var(--surface2); border: 1.5px solid var(--border2); display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: 700; color: var(--muted); flex-shrink: 0; transition: all .2s; }
        .step-on { background: var(--accent); border-color: var(--accent); color: #000; }
        .step-text { font-size: 10px; color: var(--muted); font-weight: 600; white-space: nowrap; }
        .step-line { width: 18px; height: 1px; background: var(--border); margin: 0 2px; }
        .step-line-on { background: var(--accent); }
        .field-col { display: flex; flex-direction: column; gap: 5px; }
        .field-lbl { font-size: 9px; font-weight: 800; color: var(--muted); text-transform: uppercase; letter-spacing: 1px; }
        .field-inp { background: var(--surface2); border: 1px solid var(--border2); border-radius: var(--r-sm); padding: 10px 12px; color: var(--text); font-size: 13px; font-family: var(--font); outline: none; transition: border-color .15s; width: 100%; }
        .field-inp:focus { border-color: var(--accent); }
        select.field-inp option { background: var(--surface2); }
        .field-ta { background: var(--surface2); border: 1px solid var(--border2); border-radius: var(--r-sm); padding: 10px 12px; color: var(--text); font-size: 13px; font-family: var(--font); outline: none; transition: border-color .15s; width: 100%; resize: vertical; }
        .field-ta:focus { border-color: var(--accent); }
        .err-box { background: rgba(255,69,96,.08); border: 1px solid rgba(255,69,96,.25); border-radius: var(--r-sm); padding: 8px 12px; font-size: 12px; color: var(--red); border-left: 3px solid var(--red); }
        .btn-cta { background: linear-gradient(135deg, #7c5af5, #00e5cc); color: #000; border: none; border-radius: 11px; padding: 13px; font-size: 13px; font-weight: 800; cursor: pointer; font-family: var(--font); width: 100%; transition: all .15s; }
        .btn-cta:hover { opacity: .9; }
        .btn-cta:disabled { opacity: .5; cursor: not-allowed; }
        .btn-secondary { background: transparent; border: 1px solid var(--border2); color: var(--text2); border-radius: 11px; padding: 11px; font-size: 13px; font-weight: 600; cursor: pointer; font-family: var(--font); width: 100%; transition: all .15s; }
        .btn-secondary:hover { border-color: var(--text2); color: var(--text); }
        .slot-days { display: flex; gap: 6px; flex-wrap: wrap; }
        .slot-day { padding: 7px 12px; background: var(--surface2); border: 1px solid var(--border2); border-radius: 8px; color: var(--text2); font-size: 12px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .slot-day.slot-on { background: rgba(0,229,204,.12); border-color: var(--accent); color: var(--accent); }
        .slot-times { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; }
        .slot-time { padding: 7px; background: var(--surface2); border: 1px solid var(--border2); border-radius: 7px; color: var(--text2); font-size: 12px; font-weight: 600; cursor: pointer; font-family: var(--mono); transition: all .15s; }
        .slot-time.slot-on { background: rgba(0,229,204,.12); border-color: var(--accent); color: var(--accent); }
        .booking-summary { background: var(--surface2); border: 1px solid var(--border); border-radius: 10px; padding: 12px; display: flex; gap: 16px; flex-wrap: wrap; font-size: 13px; color: var(--text2); }
        .pay-center { text-align: center; }
        .pay-amt { font-family: var(--mono); font-size: 36px; font-weight: 700; color: var(--accent); }
        .pay-sub { font-size: 12px; color: var(--muted); margin-top: 3px; }
        .mpesa-pill { display: flex; align-items: center; justify-content: center; gap: 10px; padding: 12px; background: rgba(22,163,74,.06); border: 1px solid rgba(22,163,74,.2); border-radius: 11px; }
        .pay-note { font-size: 12px; color: var(--text2); line-height: 1.6; background: rgba(0,229,204,.06); border-radius: 9px; padding: 10px 13px; border-left: 3px solid var(--accent); }
        .vital-chip { padding: 5px 11px; border-radius: 99px; border: 1px solid var(--border2); background: var(--surface2); color: var(--text2); font-size: 11px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .vital-chip-on { background: rgba(0,229,204,.12); border-color: var(--accent); color: var(--accent); }
        .triage-bar { height: 3px; background: var(--border); border-radius: 99px; overflow: hidden; }
        .triage-prog { height: 100%; background: linear-gradient(90deg, var(--accent2), var(--accent)); transition: width .35s ease; }
        .triage-step { font-size: 10px; color: var(--muted); margin-bottom: 6px; }
        .triage-q { font-family: var(--font-display); font-size: 16px; font-weight: 800; color: var(--text); margin-bottom: 14px; }
        .triage-opt { padding: 11px 15px; background: var(--surface2); border: 1px solid var(--border2); border-radius: 11px; font-size: 13px; color: var(--text); cursor: pointer; text-align: left; font-weight: 500; font-family: var(--font); transition: all .15s; width: 100%; }
        .triage-opt:hover { border-color: var(--accent); background: rgba(0,229,204,.06); color: var(--accent); }
        .triage-emergency { border-color: rgba(255,69,96,.3) !important; color: var(--red) !important; background: rgba(255,69,96,.05) !important; }
        .triage-emergency:hover { background: rgba(255,69,96,.12) !important; }

        /* ── MOBILE NAV ──────────────────────────────────────────────────── */
        .mobile-nav { display: none; position: fixed; bottom: 0; left: 0; right: 0; background: var(--surface); border-top: 1px solid var(--border); padding: 6px 0; z-index: 40; }
        .mob-nav-btn { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 5px 4px; background: transparent; border: none; color: var(--muted); font-size: 9px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all .15s; }
        .mob-nav-btn.active { color: var(--accent); }
        .mob-icon { font-size: 19px; }

        /* ── FAB ─────────────────────────────────────────────────────────── */
        .fab-wrap { position: fixed; bottom: 80px; right: 18px; z-index: 45; display: flex; flex-direction: column; align-items: flex-end; gap: 8px; }
        .fab-item { background: var(--red); color: white; border: none; border-radius: 40px; padding: 10px 18px; font-weight: 700; font-size: 12px; cursor: pointer; font-family: var(--font); box-shadow: 0 4px 16px rgba(255,69,96,.4); white-space: nowrap; }
        .fab-main { width: 52px; height: 52px; border-radius: 50%; background: linear-gradient(135deg, #7c5af5, #00e5cc); color: #000; border: none; font-size: 22px; cursor: pointer; box-shadow: 0 4px 20px rgba(124,90,245,.5); }

        /* ── RESPONSIVE ──────────────────────────────────────────────────── */
        @media (max-width: 1100px) {
          .stats-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 860px) {
          .overview-grid { grid-template-columns: 1fr; }
        }
        @media (max-width: 768px) {
          .sidebar { display: none; }
          .content { padding: 14px 14px 80px; }
          .top-hd { padding: 10px 14px; }
          .th-name { font-size: 15px; }
          .hero-row { grid-template-columns: 1fr; }
          .next-appt-card { display: none; }
          .stats-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
          .mobile-nav { display: flex; }
          .vitals-mini { grid-template-columns: repeat(2, 1fr); }
          .svc-grid { grid-template-columns: 1fr; }
          .settings-grid { grid-template-columns: 1fr; }
          .slot-times { grid-template-columns: repeat(3, 1fr); }
          .drawer { width: 100vw; }
        }
      `}</style>

      <div className="shell">
        {/* ─── SIDEBAR ─────────────────────────────────────────────────── */}
        <aside className="sidebar">
          <div className="sb-brand">
            <div className="sb-logo">
              <div className="sb-logo-glyph">⚕️</div>
              <div>
                <div className="sb-logo-name">AMEXAN</div>
                <div className="sb-logo-sub">Patient Portal</div>
              </div>
            </div>
          </div>
          <div className="sb-profile">
            <div className="sb-ava">
              {patient.photoUrl ? <img src={patient.photoUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10 }} /> : patient.name[0]}
            </div>
            <div className="sb-pname">{patient.name}</div>
            <div className="sb-pid">{patient.universalId}</div>
            {patient.condition && <div className="sb-cond">🎯 {patient.condition}</div>}
          </div>
          <nav className="sb-nav">
            {tabs.map(t => (
              <button key={t.id} className={`sb-item ${activeTab === t.id ? 'active' : ''}`} onClick={() => setActiveTab(t.id)}>
                <span className="sb-item-icon">{t.icon}</span>
                {t.label}
                {t.badge ? <span className="sb-badge">{t.badge}</span> : null}
              </button>
            ))}
          </nav>
          <div className="sb-footer">
            <button className="sb-signout" onClick={() => { signOut(auth); router.replace('/login'); }}>
              <span>🚪</span> Sign Out
            </button>
          </div>
        </aside>

        {/* ─── MAIN CONTENT ────────────────────────────────────────────── */}
        <div className="main">
          {/* Top Header */}
          <div className="top-hd">
            <div className="th-left">
              <span className="th-greeting">{getGreeting()},</span>
              <span className="th-name">{patient.name.split(' ')[0]} 👋</span>
            </div>
            <div className="th-actions">
              <button className="th-btn" onClick={() => setShowTriage(true)}>🔍 <span>Find Doctor</span></button>
              <button className="th-btn" onClick={() => setShowLogVital(true)}>📊 <span>Log Vital</span></button>
              {unreadAlerts > 0 && (
                <button className="th-btn" onClick={() => setActiveTab('overview')} style={{ borderColor: 'rgba(255,69,96,.3)', color: 'var(--red)' }}>
                  🔔 {unreadAlerts}
                </button>
              )}
              <button className="th-btn th-btn-accent" onClick={() => setShowSmartcard(true)}>🪪 <span>Smartcard</span></button>
            </div>
          </div>

          <div className="content" key={activeTab}>
            {/* Live consultation banner */}
            {activeAppts.map(a => (
              <div key={a.id} className="live-banner">
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div className="live-dot" />
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 13, color: 'var(--green)' }}>Live — Dr. {a.doctorName}</div>
                    <div style={{ fontSize: 11, color: 'var(--text2)' }}>Session active · Rejoin now</div>
                  </div>
                </div>
                <button className="btn-join-live" onClick={() => joinConsultation(a)} disabled={joining === a.id}>
                  {joining === a.id ? 'Joining…' : '🎥 Rejoin'}
                </button>
              </div>
            ))}

            {/* ── OVERVIEW TAB ── */}
            {activeTab === 'overview' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
                {/* Hero row */}
                <div className="hero-row">
                  <div className="hero-card">
                    <div className="hero-greet">{getGreeting()}</div>
                    <div className="hero-name">{patient.name}</div>
                    <div className="hero-chips">
                      {patient.bloodGroup && <span className="hero-chip">🩸 {patient.bloodGroup}</span>}
                      {patient.age && <span className="hero-chip">{patient.age} yrs</span>}
                      {patient.gender && <span className="hero-chip">{patient.gender}</span>}
                      {patient.condition && <span className="hero-chip">🎯 {patient.condition}</span>}
                      {patient.insuranceProvider && <span className="hero-chip">🏥 {patient.insuranceProvider}</span>}
                    </div>
                    {latestBP && bpInfo && (
                      <div className="hero-tip">
                        Latest BP: <strong style={{ color: bpInfo.color }}>{latestBP.systolic}/{latestBP.diastolic} mmHg ({bpInfo.label})</strong> · {fmtShort(latestBP.recordedAt)}
                      </div>
                    )}
                  </div>
                  {nextAppt && (
                    <div className="next-appt-card">
                      <div className="na-label">Next Appointment</div>
                      <div className="na-count">{countdown || 'Soon'}</div>
                      <div className="na-badge">{countdown}</div>
                      <div className="na-doctor">Dr. {nextAppt.doctorName}</div>
                      <div className="na-date">{fmtDate(nextAppt.scheduledDate || nextAppt.date)}</div>
                    </div>
                  )}
                </div>

                {/* Stats */}
                <div className="stats-grid">
                  {[
                    { icon: '❤️', val: latestBP ? `${latestBP.systolic}/${latestBP.diastolic}` : '—', lbl: 'Blood Pressure', color: bpInfo?.color || 'var(--muted)' },
                    { icon: '📅', val: String(upcomingAppts.length), lbl: 'Upcoming Visits', color: 'var(--accent2)' },
                    { icon: '💊', val: String(allPrescriptions.length), lbl: 'Active Prescriptions', color: 'var(--accent)' },
                    { icon: unreadAlerts > 0 ? '🔴' : '✅', val: String(unreadAlerts), lbl: unreadAlerts > 0 ? 'Unread Alerts' : 'All Clear', color: unreadAlerts > 0 ? 'var(--red)' : 'var(--green)' },
                  ].map(s => (
                    <div key={s.lbl} className="stat-card">
                      <span className="stat-icon">{s.icon}</span>
                      <div>
                        <div className="stat-lbl">{s.lbl}</div>
                        <div className="stat-val" style={{ color: s.color }}>{s.val}</div>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Disease tools (if condition set) */}
                {patient.condition && (
                  <DiseaseToolsPanel patientId={patient.uid} condition={patient.condition} vitals={vitals} onLogVital={() => setShowLogVital(true)} />
                )}

                {/* Alerts */}
                {alerts.filter(a => !a.read).length > 0 && (
                  <div className="panel">
                    <div className="panel-hd">
                      <div className="panel-title">🔔 Active Alerts</div>
                      <span className="count-badge" style={{ background: 'rgba(255,69,96,.12)', color: 'var(--red)' }}>{alerts.filter(a => !a.read).length}</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      {alerts.filter(a => !a.read).slice(0, 5).map(al => (
                        <div key={al.id} style={{
                          background: al.severity === 'high' ? 'rgba(255,69,96,.07)' : 'rgba(255,176,32,.05)',
                          border: `1px solid ${al.severity === 'high' ? 'rgba(255,69,96,.2)' : 'rgba(255,176,32,.2)'}`,
                          borderRadius: 10, padding: '11px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10
                        }}>
                          <div>
                            <div style={{ fontWeight: 700, fontSize: 13, color: 'var(--text)' }}>{al.title}</div>
                            <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 2 }}>{al.body}</div>
                            <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 3, fontFamily: 'var(--mono)' }}>{fmtDate(al.createdAt)}</div>
                          </div>
                          <button className="btn-sm-accent" onClick={() => updateDoc(doc(db, 'alerts', al.id), { read: true })}>Dismiss</button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="overview-grid">
                  {/* Vitals panel */}
                  <div className="panel">
                    <div className="panel-hd">
                      <div className="panel-title">📊 Latest Vitals</div>
                      <button className="btn-sm-accent" onClick={() => setShowLogVital(true)}>+ Log</button>
                    </div>
                    {latestBP && (
                      <div className="vital-main" style={{ borderColor: bpInfo?.color + '40' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <span style={{ fontSize: 26 }}>❤️</span>
                          <div>
                            <div style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5 }}>Blood Pressure</div>
                            <div className="vital-main-val" style={{ color: bpInfo?.color }}>{latestBP.systolic}/{latestBP.diastolic} <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 400 }}>mmHg</span></div>
                            {bpInfo && <span className="vital-badge" style={{ background: bpInfo.color + '20', color: bpInfo.color }}>{bpInfo.label}</span>}
                          </div>
                        </div>
                      </div>
                    )}
                    <div className="vitals-mini">
                      {[
                        { type: 'glucose', icon: '🩸', label: 'Glucose', unit: 'mmol/L' },
                        { type: 'pulse', icon: '💓', label: 'Pulse', unit: 'bpm' },
                        { type: 'weight', icon: '⚖️', label: 'Weight', unit: 'kg' },
                        { type: 'temp', icon: '🌡️', label: 'Temp', unit: '°C' },
                      ].map(v => {
                        const r = vitals.find(vi => vi.type === v.type);
                        return (
                          <div key={v.type} className="vital-mini">
                            <span style={{ fontSize: 20 }}>{v.icon}</span>
                            <span className="vital-mini-val" style={{ color: 'var(--text)' }}>{r ? r.value : '—'}</span>
                            <span style={{ fontSize: 9, color: 'var(--muted)' }}>{v.unit}</span>
                            <span style={{ fontSize: 10, color: 'var(--text2)', fontWeight: 600 }}>{v.label}</span>
                          </div>
                        );
                      })}
                    </div>
                    {vitals.length === 0 && <div className="empty-sm"><div style={{ fontSize: 28 }}>📊</div><p>No readings yet. Start tracking.</p></div>}
                  </div>

                  {/* Recent prescriptions */}
                  <div className="panel">
                    <div className="panel-hd">
                      <div className="panel-title">💊 Prescriptions</div>
                      <button className="btn-sm-accent" onClick={() => setActiveTab('prescriptions')}>View All</button>
                    </div>
                    {allPrescriptions.length === 0 ? (
                      <div className="empty-sm"><div style={{ fontSize: 28 }}>💊</div><p>Prescriptions appear after consultations.</p></div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {allPrescriptions.slice(0, 3).map((rx, i) => (
                          <div key={i} className="rx-card">
                            <div className="rx-card-hd">
                              <span className="rx-card-name">💊 {rx.medication}</span>
                              <span className="rx-card-doc">Dr. {rx.doctorName}</span>
                            </div>
                            <div className="rx-card-meta">
                              <span>{rx.dosage}</span><span>·</span><span>{rx.frequency}</span><span>·</span><span>{rx.duration}</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Recent appointments */}
                  <div className="panel full-width">
                    <div className="panel-hd">
                      <div className="panel-title">📅 Recent Appointments</div>
                      <button className="btn-sm-accent" onClick={() => setActiveTab('appointments')}>View All</button>
                    </div>
                    {appointments.length === 0 ? (
                      <div className="empty-sm">
                        <div style={{ fontSize: 32 }}>📭</div>
                        <p>No appointments yet. <button style={{ color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', fontWeight: 700, fontSize: 13 }} onClick={() => setActiveTab('discover')}>Find a doctor →</button></p>
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {appointments.slice(0, 4).map(appt => {
                          const sc = statusCfg[appt.status] || statusCfg.booked;
                          return (
                            <div key={appt.id} className="appt-card">
                              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                                <div className="appt-icon">{appt.status === 'active' ? '🟢' : appt.status === 'completed' ? '✅' : appt.status === 'cancelled' ? '❌' : '📅'}</div>
                                <div>
                                  <div className="appt-spec">{appt.specialty || 'Consultation'} {appt.firstVisit && <span className="appt-first-visit">1st Visit</span>}</div>
                                  <div className="appt-dr">Dr. {appt.doctorName}</div>
                                  <div className="appt-date">{fmtDate(appt.scheduledDate || appt.date)}</div>
                                </div>
                              </div>
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexShrink: 0 }}>
                                <span className="status-pill" style={{ background: sc.bg, color: sc.color }}>{sc.label}</span>
                                {appt.status === 'active' && <button className="btn-join-sm" onClick={() => joinConsultation(appt)} disabled={joining === appt.id}>{joining === appt.id ? '…' : '🎥 Join'}</button>}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* ── DISEASE/HEALTH TAB ── */}
            {activeTab === 'disease' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {patient.condition
                  ? <DiseaseToolsPanel patientId={patient.uid} condition={patient.condition} vitals={vitals} onLogVital={() => setShowLogVital(true)} />
                  : <div className="panel"><div className="empty-sm"><div style={{ fontSize: 40 }}>🎯</div><p>No condition assigned yet. Your doctor will set this up during consultation.</p></div></div>
                }
                {/* Labs */}
                <LabsPanel patientId={patient.uid} />
                {/* Education */}
                <EducationPanel patientId={patient.uid} condition={patient.condition} />
              </div>
            )}

            {/* ── DISCOVER TAB ── */}
            {activeTab === 'discover' && (
              <div>
                {!triageDone ? (
                  <div className="triage-prompt">
                    <div>
                      <div style={{ fontWeight: 800, fontSize: 15, color: 'var(--text)', marginBottom: 3 }}>🔍 Not sure which specialist to see?</div>
                      <p style={{ fontSize: 13, color: 'var(--text2)' }}>Answer 4 quick questions for a smart recommendation.</p>
                    </div>
                    <button className="btn-cta" onClick={() => setShowTriage(true)} style={{ width: 'auto', padding: '10px 20px', fontSize: 12 }}>Start Triage →</button>
                  </div>
                ) : (
                  <div className="triage-done">
                    <span style={{ fontSize: 13, color: 'var(--green)', fontWeight: 700 }}>✅ Showing <strong>{triageSpecialty}</strong> specialists</span>
                    <button onClick={() => { setTriageDone(false); setTriageSpecialty('All'); setSpecialtyFilter('All'); }} style={{ background: 'none', border: 'none', color: 'var(--text2)', cursor: 'pointer', fontWeight: 700, fontSize: 12 }}>Reset</button>
                  </div>
                )}

                <div className="discover-controls">
                  <div className="search-wrap">
                    <span className="search-icon">🔍</span>
                    <input className="discover-search" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search doctors, specialties, clinics…" />
                  </div>
                </div>

                {/* Specialty pills */}
                <div className="pills">
                  {specialties.map(sp => <button key={sp} className={`pill ${specialtyFilter === sp ? 'on' : ''}`} onClick={() => setSpecialtyFilter(sp)}>{sp}</button>)}
                </div>

                {/* Clinic pills */}
                <div className="pills" style={{ marginTop: -8 }}>
                  {clinics.map(cl => <button key={cl} className={`pill ${clinicFilter === cl ? 'on' : ''}`} onClick={() => setClinicFilter(cl)}>{cl}</button>)}
                </div>

                <p style={{ fontSize: 11, color: 'var(--muted)', marginBottom: 14 }}>
                  Showing <strong style={{ color: 'var(--text)' }}>{filteredSvcs.length}</strong> doctor{filteredSvcs.length !== 1 ? 's' : ''}
                </p>

                {filteredSvcs.length === 0 ? (
                  <div className="panel"><div className="empty-sm"><div style={{ fontSize: 40 }}>🔭</div><p>No doctors match your filters.</p></div></div>
                ) : (
                  <div className="svc-grid">
                    {filteredSvcs.map(svc => (
                      <div key={svc.id} className="svc-card" onClick={() => setProfileSvc(svc)}>
                        <div className="svc-card-banner" />
                        <div className="svc-card-body">
                          <div className="svc-card-hd">
                            <div className="svc-spec">{svc.specialty}</div>
                            <div className="svc-price">KES {svc.price.toLocaleString()}</div>
                          </div>
                          <div className="svc-doc-row">
                            <div className="svc-doc-ava">
                              {svc.photo ? <img src={svc.photo} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 9 }} /> : svc.doctorName[0]}
                            </div>
                            <div>
                              <div className="svc-doc-name">Dr. {svc.doctorName}</div>
                              <div className="svc-doc-clinic">{svc.clinic} {svc.location && `· ${svc.location}`}</div>
                            </div>
                          </div>
                          <div className="svc-chips">
                            <span className="svc-chip">⏱ {svc.duration} min</span>
                            {svc.rating && <span className="svc-chip">⭐ {svc.rating}</span>}
                            {svc.yearsExperience && <span className="svc-chip">🏆 {svc.yearsExperience} yrs</span>}
                            {svc.acceptsInsurance && <span className="svc-chip">🏥 Insurance</span>}
                            <span className="svc-chip">🟢 Available</span>
                          </div>
                          {svc.description && <p className="svc-desc">{svc.description.slice(0, 100)}{svc.description.length > 100 ? '…' : ''}</p>}
                        </div>
                        <div className="svc-card-footer" onClick={e => e.stopPropagation()}>
                          <button className="btn-view-profile" onClick={() => setProfileSvc(svc)}>View Profile</button>
                          <button className="btn-book" onClick={() => { setProfileSvc(null); setBookSvc(svc); }}>Book Now</button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* ── VITALS TAB ── */}
            {activeTab === 'vitals' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="panel">
                  <div className="panel-hd">
                    <div className="panel-title">📊 Vital Signs History</div>
                    <button className="btn-sm-accent" onClick={() => setShowLogVital(true)}>+ Log Reading</button>
                  </div>
                  {latestBP && bpInfo && (
                    <div className="vital-main" style={{ borderColor: bpInfo.color + '40', marginBottom: 16 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
                        <span style={{ fontSize: 28 }}>❤️</span>
                        <div>
                          <div style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5 }}>Blood Pressure (Latest)</div>
                          <div className="vital-main-val" style={{ color: bpInfo.color }}>{latestBP.systolic}/{latestBP.diastolic} <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 400 }}>mmHg</span></div>
                          <span className="vital-badge" style={{ background: bpInfo.color + '20', color: bpInfo.color }}>{bpInfo.label}</span>
                        </div>
                      </div>
                      {vitals.filter(v => v.type === 'bp').length > 1 && (
                        <>
                          <div style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>7-Day Trend</div>
                          <div className="bp-sparkline-row">
                            {vitals.filter(v => v.type === 'bp').slice(0, 7).reverse().map((v, i) => {
                              const pct = Math.min(100, Math.max(5, ((v.systolic! - 80) / 80) * 100));
                              const cat = bpCat(v.systolic!, v.diastolic!);
                              return (
                                <div key={i} className="spark-col" title={`${v.systolic}/${v.diastolic} — ${fmtShort(v.recordedAt)}`}>
                                  <div className="spark-bar-outer"><div className="spark-bar-inner" style={{ height: `${pct}%`, background: cat.color }} /></div>
                                  <div className="spark-date">{fmtShort(v.recordedAt)}</div>
                                </div>
                              );
                            })}
                          </div>
                        </>
                      )}
                    </div>
                  )}
                  <div className="vitals-mini" style={{ marginBottom: 16 }}>
                    {[
                      { type: 'glucose', icon: '🩸', label: 'Glucose', unit: 'mmol/L' },
                      { type: 'pulse', icon: '💓', label: 'Pulse', unit: 'bpm' },
                      { type: 'weight', icon: '⚖️', label: 'Weight', unit: 'kg' },
                      { type: 'temp', icon: '🌡️', label: 'Temp', unit: '°C' },
                    ].map(v => {
                      const r = vitals.find(vi => vi.type === v.type);
                      return (
                        <div key={v.type} className="vital-mini">
                          <span style={{ fontSize: 22 }}>{v.icon}</span>
                          <span className="vital-mini-val" style={{ color: 'var(--text)' }}>{r ? r.value : '—'}</span>
                          <span style={{ fontSize: 9, color: 'var(--muted)' }}>{v.unit}</span>
                          <span style={{ fontSize: 10, color: 'var(--text2)', fontWeight: 600 }}>{v.label}</span>
                        </div>
                      );
                    })}
                  </div>
                  {vitals.length === 0 ? (
                    <div className="empty-sm"><div style={{ fontSize: 36 }}>📊</div><p>No readings yet. Log your first vital sign to start tracking.</p></div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      <div style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>All Readings</div>
                      {vitals.slice(0, 20).map(v => (
                        <div key={v.id} style={{ background: 'var(--surface2)', border: '1px solid var(--border)', borderRadius: 9, padding: '9px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                            <span style={{ fontSize: 16 }}>{v.type === 'bp' ? '❤️' : v.type === 'glucose' ? '🩸' : v.type === 'weight' ? '⚖️' : v.type === 'temp' ? '🌡️' : '💓'}</span>
                            <div>
                              <div style={{ fontWeight: 700, fontSize: 13, fontFamily: 'var(--mono)' }}>{v.value} {v.unit}</div>
                              {v.note && <div style={{ fontSize: 11, color: 'var(--muted)', fontStyle: 'italic' }}>{v.note}</div>}
                            </div>
                          </div>
                          <div style={{ fontSize: 11, color: 'var(--muted)', fontFamily: 'var(--mono)' }}>{fmtDate(v.recordedAt)}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* ── APPOINTMENTS TAB ── */}
            {activeTab === 'appointments' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {[
                    { label: 'All', count: appointments.length },
                    { label: 'Upcoming', count: upcomingAppts.length },
                    { label: 'Active', count: activeAppts.length },
                    { label: 'Completed', count: appointments.filter(a => a.status === 'completed').length },
                    { label: 'Cancelled', count: appointments.filter(a => a.status === 'cancelled').length },
                  ].map(f => (
                    <div key={f.label} style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 9, padding: '7px 13px', fontSize: 12, fontWeight: 700 }}>
                      {f.label} <span style={{ color: 'var(--accent)', fontFamily: 'var(--mono)' }}>{f.count}</span>
                    </div>
                  ))}
                </div>
                {appointments.length === 0 ? (
                  <div className="panel"><div className="empty-sm"><div style={{ fontSize: 40 }}>📭</div><p>No appointments yet.</p><button className="btn-sm-accent" style={{ marginTop: 12 }} onClick={() => setActiveTab('discover')}>Find Doctors →</button></div></div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {appointments.map(appt => {
                      const sc = statusCfg[appt.status] || statusCfg.booked;
                      return (
                        <div key={appt.id} className="appt-card">
                          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                            <div className="appt-icon">{appt.status === 'active' ? '🟢' : appt.status === 'completed' ? '✅' : appt.status === 'cancelled' ? '❌' : '📅'}</div>
                            <div>
                              <div className="appt-spec">
                                {appt.specialty || 'Consultation'}
                                {appt.firstVisit && <span className="appt-first-visit">1st Visit</span>}
                                {appt.type === 'telemedicine' && <span style={{ fontSize: 9, color: 'var(--accent)', fontWeight: 700, marginLeft: 6 }}>💻 VIDEO</span>}
                              </div>
                              <div className="appt-dr">Dr. {appt.doctorName}</div>
                              <div className="appt-date">{fmtDate(appt.scheduledDate || appt.date)}</div>
                              {appt.scheduledTime && <div style={{ fontSize: 10, color: 'var(--accent)', fontFamily: 'var(--mono)', marginTop: 1 }}>⏰ {appt.scheduledTime}</div>}
                              {appt.patientNotes && <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 3, fontStyle: 'italic' }}>"{appt.patientNotes.slice(0, 60)}…"</div>}
                              {appt.paymentStatus && (
                                <div style={{ fontSize: 10, marginTop: 3, color: appt.paymentStatus === 'paid' ? 'var(--green)' : appt.paymentStatus === 'failed' ? 'var(--red)' : 'var(--amber)', fontWeight: 700 }}>
                                  💳 {appt.paymentStatus === 'paid' ? `Paid · Ref: ${appt.paymentRef}` : appt.paymentStatus === 'processing' ? 'Payment processing…' : appt.paymentStatus === 'failed' ? 'Payment failed — ' : 'Pending payment'}
                                  {appt.paymentStatus === 'failed' && <button style={{ background: 'none', border: 'none', color: 'var(--amber)', cursor: 'pointer', fontWeight: 700, fontSize: 10 }} onClick={() => setActiveTab('payments')}>Pay Now →</button>}
                                </div>
                              )}
                            </div>
                          </div>
                          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexShrink: 0, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                            <span className="status-pill" style={{ background: sc.bg, color: sc.color }}>{sc.label}</span>
                            {appt.status === 'active' && (
                              <button className="btn-join-sm" onClick={() => joinConsultation(appt)} disabled={joining === appt.id}>
                                {joining === appt.id ? '…' : '🎥 Join'}
                              </button>
                            )}
                            {appt.status === 'completed' && (
                              <button className="btn-records" onClick={() => setActiveTab('history')}>📄 History</button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}

            {/* ── PRESCRIPTIONS TAB ── */}
            {activeTab === 'prescriptions' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="panel">
                  <div className="panel-hd">
                    <div className="panel-title">💊 Active Prescriptions</div>
                    <span className="count-badge">{allPrescriptions.length}</span>
                  </div>
                  {allPrescriptions.length === 0 ? (
                    <div className="empty-sm"><div style={{ fontSize: 36 }}>💊</div><p>Prescriptions appear here after doctor consultations.</p></div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                      {allPrescriptions.map((rx, i) => (
                        <div key={i} className="rx-card">
                          <div className="rx-card-hd">
                            <div>
                              <div className="rx-card-name">💊 {rx.medication}</div>
                              <div className="rx-card-doc">Prescribed by Dr. {rx.doctorName}</div>
                            </div>
                            <div style={{ textAlign: 'right', fontSize: 11, color: 'var(--muted)', fontFamily: 'var(--mono)' }}>
                              {rx.addedAt ? new Date(rx.addedAt).toLocaleDateString() : '—'}
                            </div>
                          </div>
                          <div className="rx-card-meta">
                            <span>📏 {rx.dosage}</span><span>·</span>
                            <span>🔁 {rx.frequency}</span><span>·</span>
                            <span>⏳ {rx.duration}</span>
                            {rx.refills ? <><span>·</span><span>🔄 {rx.refills} refills</span></> : null}
                          </div>
                          {rx.instructions && <div className="rx-card-instructions">📌 {rx.instructions}</div>}
                          {/* Adherence calendar */}
                          <div style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, marginTop: 10, marginBottom: 4 }}>7-Day Adherence — tap a day to mark as taken</div>
                          <PrescriptionCalendar rx={{ ...rx, apptId: rx.apptId }} patientId={patient.uid} apptId={rx.apptId} />
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* ── LABS TAB ── */}
            {activeTab === 'labs' && <LabsPanel patientId={patient.uid} />}

            {/* ── HISTORY TAB ── */}
            {activeTab === 'history' && <ClinicalHistoryPanel patientId={patient.uid} patient={patient} />}

            {/* ── MESSAGES TAB ── */}
            {activeTab === 'messages' && <MessagesPanel patient={patient} appointments={appointments} />}

            {/* ── EDUCATION TAB ── */}
            {activeTab === 'education' && <EducationPanel patientId={patient.uid} condition={patient.condition} />}

            {/* ── PAYMENTS TAB ── */}
            {activeTab === 'payments' && <PaymentsPanel appointments={appointments} patient={patient} />}

            {/* ── SETTINGS TAB ── */}
            {activeTab === 'settings' && (
              <SettingsPanel patient={patient} onUpdate={updates => setPatient(p => p ? { ...p, ...updates } : p)} />
            )}
          </div>
        </div>
      </div>

      {/* Mobile Bottom Nav */}
      <nav className="mobile-nav">
        {[
          { id: 'overview', icon: '🏠', label: 'Home' },
          { id: 'discover', icon: '🔍', label: 'Discover' },
          { id: 'disease', icon: '🎯', label: 'My Health' },
          { id: 'appointments', icon: '📅', label: 'Visits' },
          { id: 'messages', icon: '💬', label: 'Messages' },
        ].map(t => (
          <button key={t.id} className={`mob-nav-btn ${activeTab === t.id ? 'active' : ''}`} onClick={() => setActiveTab(t.id)}>
            <span className="mob-icon">{t.icon}</span>
            {t.label}
          </button>
        ))}
      </nav>

      {/* FAB */}
      <div className="fab-wrap">
        <button className="fab-item" onClick={() => setShowEmergency(true)}>🚨 Emergency</button>
        <button className="fab-main" onClick={() => setShowLogVital(true)}>+</button>
      </div>

      {/* ─── MODALS & DRAWERS ─────────────────────────────────────────── */}
      {profileSvc && (
        <DoctorProfileDrawer
          svc={profileSvc}
          onClose={() => setProfileSvc(null)}
          onBook={() => { setBookSvc(profileSvc); setProfileSvc(null); }}
        />
      )}
      {bookSvc && <BookModal svc={bookSvc} patient={patient} onClose={() => setBookSvc(null)} />}
      {showLogVital && <LogVitalModal patient={patient} onClose={() => setShowLogVital(false)} onSaved={() => {}} />}
      {showTriage && <TriageModal onClose={() => setShowTriage(false)} onDone={sp => { setTriageSpecialty(sp); setTriageDone(true); setShowTriage(false); setActiveTab('discover'); }} />}
      {showSmartcard && <SmartcardModal patient={patient} onClose={() => setShowSmartcard(false)} />}
      {showEmergency && <EmergencyModal onClose={() => setShowEmergency(false)} patientId={patient.uid} />}
    </>
  );
}
