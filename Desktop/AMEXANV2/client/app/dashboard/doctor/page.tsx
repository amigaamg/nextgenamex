'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import {
  collection, query, where, onSnapshot, doc,
  addDoc, updateDoc, getDoc, getDocs, serverTimestamp,
  orderBy, deleteDoc,
} from 'firebase/firestore';
import { signOut, onAuthStateChanged } from 'firebase/auth';
import { v4 as uuidv4 } from 'uuid';

// -----------------------------------------------------------------------------
// TYPES
// -----------------------------------------------------------------------------
interface DoctorProfile {
  uid: string;
  name: string;
  email: string;
  specialty: string;
  clinic?: string;
  licenseNumber?: string;
  phone?: string;
  bio?: string;
  yearsExperience?: number;
  languages?: string[];
  location?: string;
}

interface Service {
  id: string;
  specialty: string;
  clinic: string;
  price: number;
  description: string;
  doctorId: string;
  doctorName: string;
  duration: number;
  isAvailable: boolean;
  tags?: string[];
  rating?: number;
  yearsExperience?: number;
  location?: string;
  createdAt: any;
}

interface Appointment {
  id: string;
  patientId: string;
  patientName?: string;
  patientEmail?: string;
  patientPhone?: string;
  serviceId: string;
  specialty?: string;
  status: 'booked' | 'active' | 'completed' | 'cancelled';
  date: any;
  patientNotes?: string;
  notes?: string;
  prescriptions?: Prescription[];
  consultationId?: string;
  doctorId: string;
  amount?: number;
  paymentStatus?: string;
}

interface Consultation {
  id: string;
  appointmentId: string;
  doctorId: string;
  patientId: string;
  status: 'active' | 'completed';
  prescriptions: Prescription[];
  notes: string;
  startedAt: any;
}

interface Prescription {
  medication: string;
  dosage: string;
  frequency: string;
  duration: string;
  addedAt: string;
}

interface VitalReading {
  id: string;
  patientId: string;
  type: 'bp' | 'glucose' | 'weight' | 'temp' | 'pulse';
  value: string;
  systolic?: number;
  diastolic?: number;
  unit: string;
  recordedAt: any;
  note?: string;
}

interface ChatMessage {
  id: string;
  threadId: string;
  text: string;
  senderId: string;
  senderRole: 'doctor' | 'patient';
  timestamp: any;
  read: boolean;
}

interface PatientRecord {
  uid: string;
  name: string;
  email: string;
  phone?: string;
  age?: number;
  gender?: string;
  bloodGroup?: string;
  condition?: string;
  allergies?: string[];
  emergencyContact?: string;
}

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------
const fmtDate = (ts: any) => {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-KE', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
};

const fmtShort = (ts: any) => {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-KE', { day: 'numeric', month: 'short' });
};

const isToday = (ts: any) => {
  if (!ts) return false;
  const d = ts?.toDate ? ts.toDate() : new Date(ts);
  return d.toDateString() === new Date().toDateString();
};

const getGreeting = () => {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
};

const bpCategory = (s: number, d: number) => {
  if (s < 120 && d < 80) return { label: 'Normal', color: '#10b981' };
  if (s < 130 && d < 80) return { label: 'Elevated', color: '#f59e0b' };
  if (s < 140 || d < 90) return { label: 'High Stage 1', color: '#f97316' };
  return { label: 'High Stage 2', color: '#ef4444' };
};

const statusConfig: Record<string, { label: string; color: string; bg: string }> = {
  booked:    { label: 'Upcoming',  color: '#6366f1', bg: 'rgba(99,102,241,0.1)' },
  active:    { label: '● Live',    color: '#10b981', bg: 'rgba(16,185,129,0.1)' },
  completed: { label: 'Completed', color: '#64748b', bg: 'rgba(100,116,139,0.1)' },
  cancelled: { label: 'Cancelled', color: '#ef4444', bg: 'rgba(239,68,68,0.1)' },
};

// -----------------------------------------------------------------------------
// MODALS
// -----------------------------------------------------------------------------

// --- Service Modal (create/edit) ----------------------------------------------
function ServiceModal({ doctor, existing, onClose }: {
  doctor: DoctorProfile;
  existing?: Service;
  onClose: () => void;
}) {
  const [form, setForm] = useState({
    specialty:  existing?.specialty || doctor.specialty || '',
    clinic:     existing?.clinic    || doctor.clinic    || '',
    price:      existing?.price?.toString() || '',
    duration:   existing?.duration?.toString() || '30',
    description: existing?.description || '',
    location:   existing?.location  || doctor.location || '',
    tags:       existing?.tags?.join(', ') || '',
    yearsExperience: existing?.yearsExperience?.toString() || doctor.yearsExperience?.toString() || '',
    rating:     existing?.rating?.toString() || '',
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr]       = useState('');

  const f = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setForm(p => ({ ...p, [k]: e.target.value }));

  const save = async () => {
    if (!form.specialty || !form.clinic || !form.price) { setErr('Fill all required fields.'); return; }
    setSaving(true); setErr('');
    try {
      const payload = {
        specialty: form.specialty,
        clinic: form.clinic,
        price: Number(form.price),
        duration: Number(form.duration),
        description: form.description,
        location: form.location,
        tags: form.tags.split(',').map(t => t.trim()).filter(Boolean),
        yearsExperience: form.yearsExperience ? Number(form.yearsExperience) : null,
        rating: form.rating ? Number(form.rating) : null,
        doctorId: doctor.uid,
        doctorName: doctor.name,
        isAvailable: true,
      };
      if (existing) {
        await updateDoc(doc(db, 'services', existing.id), payload);
      } else {
        await addDoc(collection(db, 'services'), { ...payload, createdAt: serverTimestamp() });
      }
      onClose();
    } catch (e: any) { setErr(e.message); }
    setSaving(false);
  };

  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 580 }}>
        <div className="modal-hd">
          <h3 className="modal-ht">{existing ? 'Edit Service' : 'Create New Service'}</h3>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          <div className="form-grid-2">
            <div className="field-col">
              <label className="field-lbl">Specialty *</label>
              <input className="field-inp" value={form.specialty} onChange={f('specialty')} placeholder="e.g. Cardiology" />
            </div>
            <div className="field-col">
              <label className="field-lbl">Clinic / Service Name *</label>
              <input className="field-inp" value={form.clinic} onChange={f('clinic')} placeholder="e.g. Heart Health Clinic" />
            </div>
            <div className="field-col">
              <label className="field-lbl">Fee (KES) *</label>
              <input className="field-inp" type="number" value={form.price} onChange={f('price')} placeholder="2500" />
            </div>
            <div className="field-col">
              <label className="field-lbl">Duration (min)</label>
              <select className="field-inp" value={form.duration} onChange={f('duration')}>
                {[15, 20, 30, 45, 60, 90].map(d => <option key={d} value={d}>{d} min</option>)}
              </select>
            </div>
            <div className="field-col">
              <label className="field-lbl">Location</label>
              <input className="field-inp" value={form.location} onChange={f('location')} placeholder="e.g. Nairobi CBD" />
            </div>
            <div className="field-col">
              <label className="field-lbl">Years Experience</label>
              <input className="field-inp" type="number" value={form.yearsExperience} onChange={f('yearsExperience')} placeholder="e.g. 12" />
            </div>
            <div className="field-col form-full">
              <label className="field-lbl">Tags (comma-separated)</label>
              <input className="field-inp" value={form.tags} onChange={f('tags')} placeholder="e.g. Virtual, Paediatrics, Urgent" />
            </div>
            <div className="field-col form-full">
              <label className="field-lbl">Description</label>
              <textarea className="field-ta" rows={3} value={form.description} onChange={f('description')} placeholder="What does this service offer patients?" />
            </div>
          </div>
          {err && <div className="err-box">{err}</div>}
          <div style={{ display: 'flex', gap: 10 }}>
            <button className="btn-secondary" onClick={onClose} style={{ flex: 1 }}>Cancel</button>
            <button className="btn-cta" onClick={save} disabled={saving} style={{ flex: 2 }}>
              {saving ? 'Saving…' : existing ? 'Save Changes' : 'Create Service'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// --- Prescription Modal --------------------------------------------------------
function PrescriptionModal({ consultationId, appointmentId, existing, onClose, onSaved }: {
  consultationId: string;
  appointmentId: string;
  existing: Prescription[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [rx, setRx] = useState<Prescription>({ medication: '', dosage: '', frequency: '', duration: '', addedAt: new Date().toISOString() });
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (!rx.medication || !rx.dosage) return;
    setSaving(true);
    const newRx = [...existing, { ...rx, addedAt: new Date().toISOString() }];
    try {
      await updateDoc(doc(db, 'consultations', consultationId), { prescriptions: newRx });
      await updateDoc(doc(db, 'appointments', appointmentId), { prescriptions: newRx });
      onSaved();
      onClose();
    } catch (e) { console.error(e); }
    setSaving(false);
  };

  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
        <div className="modal-hd">
          <h3 className="modal-ht">💊 Add Prescription</h3>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          {[
            { k: 'medication', label: 'Medication *', ph: 'e.g. Amlodipine 5mg' },
            { k: 'dosage',     label: 'Dosage *',     ph: 'e.g. 1 tablet' },
            { k: 'frequency',  label: 'Frequency',    ph: 'e.g. Once daily' },
            { k: 'duration',   label: 'Duration',     ph: 'e.g. 30 days' },
          ].map(f => (
            <div key={f.k} className="field-col">
              <label className="field-lbl">{f.label}</label>
              <input className="field-inp" value={(rx as any)[f.k]} onChange={e => setRx(p => ({ ...p, [f.k]: e.target.value }))} placeholder={f.ph} />
            </div>
          ))}
          <button className="btn-cta" onClick={save} disabled={saving || !rx.medication}>
            {saving ? 'Saving…' : '💊 Add Prescription'}
          </button>
        </div>
      </div>
    </div>
  );
}

// --- Patient Detail Modal ------------------------------------------------------
function PatientDetailModal({ patient, doctorId, onClose }: { patient: PatientRecord; doctorId: string; onClose: () => void }) {
  const [vitals, setVitals]   = useState<VitalReading[]>([]);
  const [appts,  setAppts]    = useState<Appointment[]>([]);

  useEffect(() => {
    const unsubV = onSnapshot(
      query(collection(db, 'vitals'), where('patientId', '==', patient.uid), orderBy('recordedAt', 'desc')),
      snap => setVitals(snap.docs.map(d => ({ id: d.id, ...d.data() } as VitalReading)))
    );
    const unsubA = onSnapshot(
      query(collection(db, 'appointments'), where('patientId', '==', patient.uid), where('doctorId', '==', doctorId), orderBy('date', 'desc')),
      snap => setAppts(snap.docs.map(d => ({ id: d.id, ...d.data() } as Appointment)))
    );
    return () => { unsubV(); unsubA(); };
  }, [patient.uid, doctorId]);

  const latestBP   = vitals.find(v => v.type === 'bp');
  const bpCat      = latestBP ? bpCategory(latestBP.systolic!, latestBP.diastolic!) : null;
  const allRx      = appts.flatMap(a => a.prescriptions || []);

  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 580, maxHeight: '90vh' }}>
        <div className="modal-hd">
          <div>
            <h3 className="modal-ht">{patient.name}</h3>
            <p className="modal-hs">{patient.email} {patient.phone ? `· ${patient.phone}` : ''}</p>
          </div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {[
              patient.bloodGroup && `🩸 ${patient.bloodGroup}`,
              patient.age && `${patient.age} yrs`,
              patient.gender,
              patient.condition,
            ].filter(Boolean).map(c => (
              <span key={c as string} className="info-chip">{c}</span>
            ))}
          </div>
          {patient.allergies?.length ? (
            <div className="allergy-box">⚠️ Allergies: {patient.allergies.join(', ')}</div>
          ) : null}

          <div className="patient-detail-section">
            <div className="pd-section-title">❤️ Latest Vitals</div>
            <div className="vitals-summary-grid">
              {[
                { type: 'bp',      icon: '❤️', label: 'BP',      val: latestBP ? `${latestBP.systolic}/${latestBP.diastolic}` : '—', sub: bpCat?.label, color: bpCat?.color },
                { type: 'glucose', icon: '🩸', label: 'Glucose', val: vitals.find(v => v.type === 'glucose')?.value || '—', sub: 'mmol/L' },
                { type: 'pulse',   icon: '💓', label: 'Pulse',   val: vitals.find(v => v.type === 'pulse')?.value   || '—', sub: 'bpm' },
                { type: 'weight',  icon: '⚖️', label: 'Weight',  val: vitals.find(v => v.type === 'weight')?.value  || '—', sub: 'kg' },
              ].map(v => (
                <div key={v.type} className="vs-card">
                  <span className="vs-icon">{v.icon}</span>
                  <span className="vs-val" style={{ color: v.color || 'var(--text)' }}>{v.val}</span>
                  <span className="vs-label">{v.label}</span>
                  {v.sub && <span className="vs-sub" style={{ color: v.color }}>{v.sub}</span>}
                </div>
              ))}
            </div>
          </div>

          <div className="patient-detail-section">
            <div className="pd-section-title">📅 Visit History ({appts.length})</div>
            {appts.length === 0 ? <p className="rec-empty">No shared appointments yet.</p> : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {appts.slice(0, 4).map(a => {
                  const sc = statusConfig[a.status] || statusConfig.booked;
                  return (
                    <div key={a.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 12px', background: 'var(--bg)', borderRadius: 10, border: '1px solid var(--border)' }}>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 700 }}>{a.specialty || 'Consultation'}</div>
                        <div style={{ fontSize: 11, color: 'var(--muted)', fontFamily: 'var(--mono)' }}>{fmtDate(a.date)}</div>
                      </div>
                      <span className="status-pill" style={{ background: sc.bg, color: sc.color }}>{sc.label}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="patient-detail-section">
            <div className="pd-section-title">💊 Prescriptions ({allRx.length})</div>
            {allRx.length === 0 ? <p className="rec-empty">No prescriptions yet.</p> : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {allRx.slice(0, 4).map((rx, i) => (
                  <div key={i} className="rx-row">
                    <span className="rx-name">💊 {rx.medication}</span>
                    <span className="rx-detail">{rx.dosage} · {rx.frequency} · {rx.duration}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <button className="btn-secondary" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

// --- Notes Modal ---------------------------------------------------------------
function NotesModal({ consultationId, appointmentId, currentNotes, onClose, onSaved }: {
  consultationId: string; appointmentId: string; currentNotes: string;
  onClose: () => void; onSaved: () => void;
}) {
  const [notes, setNotes] = useState(currentNotes);
  const [saving, setSaving] = useState(false);
  const save = async () => {
    setSaving(true);
    await updateDoc(doc(db, 'consultations', consultationId), { notes });
    await updateDoc(doc(db, 'appointments',  appointmentId),  { notes });
    onSaved(); onClose();
    setSaving(false);
  };
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
        <div className="modal-hd">
          <h3 className="modal-ht">📝 Clinical Notes</h3>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          <div className="field-col">
            <label className="field-lbl">Notes (visible to patient after session)</label>
            <textarea className="field-ta" rows={8} value={notes} onChange={e => setNotes(e.target.value)}
              placeholder="Document findings, recommendations, referrals…" />
          </div>
          <button className="btn-cta" onClick={save} disabled={saving}>{saving ? 'Saving…' : '💾 Save Notes'}</button>
        </div>
      </div>
    </div>
  );
}

// -----------------------------------------------------------------------------
// PANELS
// -----------------------------------------------------------------------------

// --- Chat Panel ----------------------------------------------------------------
function ChatPanel({ doctorId, patients }: { doctorId: string; patients: PatientRecord[] }) {
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null);
  const [msgs,  setMsgs]  = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!selectedPatientId) return;
    const threadId = [doctorId, selectedPatientId].sort().join('_');
    const unsub = onSnapshot(
      query(collection(db, 'messages'), where('threadId', '==', threadId), orderBy('timestamp', 'asc')),
      snap => setMsgs(snap.docs.map(d => ({ id: d.id, ...d.data() } as ChatMessage)))
    );
    return () => unsub();
  }, [selectedPatientId, doctorId]);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [msgs]);

  const send = async () => {
    if (!input.trim() || !selectedPatientId) return;
    const threadId = [doctorId, selectedPatientId].sort().join('_');
    await addDoc(collection(db, 'messages'), {
      threadId,
      text: input,
      senderId: doctorId,
      senderRole: 'doctor',
      timestamp: serverTimestamp(),
      read: false,
    });
    setInput('');
  };

  const selectedPatient = patients.find(p => p.uid === selectedPatientId);

  return (
    <div className="chat-shell">
      <div className="chat-sidebar">
        <div className="chat-sidebar-hd">💬 Patient Conversations</div>
        {patients.length === 0 ? (
          <div className="empty-sm">No patients yet.</div>
        ) : (
          patients.map(p => (
            <button key={p.uid} className={`chat-patient-btn ${selectedPatientId === p.uid ? 'active' : ''}`}
              onClick={() => setSelectedPatientId(p.uid)}>
              <div className="chat-patient-ava">{p.name[0]}</div>
              <div className="chat-patient-info">
                <span className="chat-patient-name">{p.name}</span>
                <span className="chat-patient-sub">{p.condition || p.email}</span>
              </div>
            </button>
          ))
        )}
      </div>
      <div className="chat-area">
        {!selectedPatientId ? (
          <div className="chat-empty">
            <div style={{ fontSize: 48, marginBottom: 12 }}>💬</div>
            <p style={{ fontWeight: 700, fontSize: 15 }}>Select a patient to message</p>
            <p style={{ fontSize: 13, color: 'var(--muted)', marginTop: 4 }}>Messages sync in real-time with the patient's dashboard.</p>
          </div>
        ) : (
          <>
            <div className="chat-area-hd">
              <div className="chat-patient-ava">{selectedPatient?.name[0]}</div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 14 }}>{selectedPatient?.name}</div>
                <div style={{ fontSize: 11, color: 'var(--muted)' }}>{selectedPatient?.condition || 'Patient'}</div>
              </div>
            </div>
            <div className="chat-feed">
              {msgs.length === 0 && <div className="empty-sm">No messages yet. Say hello 👋</div>}
              {msgs.map(m => (
                <div key={m.id} className={`msg-bubble-wrap ${m.senderId === doctorId ? 'mine' : 'theirs'}`}>
                  <div className={`msg-bubble ${m.senderId === doctorId ? 'msg-mine' : 'msg-theirs'}`}>
                    <div className="msg-sender">{m.senderRole === 'doctor' ? 'You' : selectedPatient?.name}</div>
                    {m.text}
                  </div>
                </div>
              ))}
              <div ref={endRef} />
            </div>
            <div className="chat-input-row">
              <input className="chat-inp" value={input} onChange={e => setInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && send()} placeholder="Type a message to patient…" />
              <button className="chat-send" onClick={send}>→</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// --- Active Consultation Panel ------------------------------------------------
function ActiveConsultationsPanel({ doctorId, appointments, onStarted }: {
  doctorId: string;
  appointments: Appointment[];
  onStarted: () => void;
}) {
  const router = useRouter();
  const [starting, setStarting] = useState<string | null>(null);
  const [consultations, setConsultations] = useState<Record<string, Consultation>>({});
  const [showRx, setShowRx] = useState<{ cId: string; aId: string; existing: Prescription[] } | null>(null);
  const [showNotes, setShowNotes] = useState<{ cId: string; aId: string; notes: string } | null>(null);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'consultations'), where('doctorId', '==', doctorId), where('status', '==', 'active')),
      snap => {
        const map: Record<string, Consultation> = {};
        snap.docs.forEach(d => { map[d.data().appointmentId] = { id: d.id, ...d.data() } as Consultation; });
        setConsultations(map);
      }
    );
    return () => unsub();
  }, [doctorId]);

  const startConsultation = async (appt: Appointment) => {
    setStarting(appt.id);
    try {
      const consultationId = uuidv4();
      await setDoc(doc(db, 'consultations', consultationId), {
        appointmentId: appt.id,
        doctorId:      appt.doctorId,
        patientId:     appt.patientId,
        status:        'active',
        prescriptions: [],
        notes:         '',
        startedAt:     serverTimestamp(),
      });
      await updateDoc(doc(db, 'appointments', appt.id), {
        status: 'active',
        consultationId,
      });
      onStarted();
      router.push(`/dashboard/consultation/${consultationId}`);
    } catch (e) { console.error(e); alert('Failed to start session.'); }
    setStarting(null);
  };

  const endConsultation = async (appt: Appointment) => {
    const c = consultations[appt.id];
    if (!c) return;
    await updateDoc(doc(db, 'consultations', c.id), { status: 'completed', endedAt: serverTimestamp() });
    await updateDoc(doc(db, 'appointments',  appt.id), { status: 'completed' });
  };

  const active   = appointments.filter(a => a.status === 'active');
  const upcoming = appointments.filter(a => a.status === 'booked');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {active.length > 0 && (
        <div className="panel active-sessions-panel">
          <div className="panel-hd">
            <div className="panel-title"><span className="live-dot-sm" />Active Sessions ({active.length})</div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {active.map(appt => {
              const c = consultations[appt.id];
              return (
                <div key={appt.id} className="active-session-card">
                  <div className="as-left">
                    <div className="as-ava">{(appt.patientName || 'P')[0]}</div>
                    <div>
                      <div className="as-name">{appt.patientName || 'Patient'}</div>
                      <div className="as-sub">{appt.specialty}</div>
                      {appt.patientNotes && <div className="as-concern">"{appt.patientNotes}"</div>}
                    </div>
                  </div>
                  <div className="as-actions">
                    {c && (
                      <>
                        <button className="btn-action" onClick={() => setShowRx({ cId: c.id, aId: appt.id, existing: c.prescriptions })}>
                          💊 Add Rx
                        </button>
                        <button className="btn-action" onClick={() => setShowNotes({ cId: c.id, aId: appt.id, notes: c.notes })}>
                          📝 Notes
                        </button>
                      </>
                    )}
                    <button className="btn-join-live" onClick={() => router.push(`/dashboard/consultation/${c?.id || ''}`)}>
                      🎥 Rejoin
                    </button>
                    <button className="btn-end" onClick={() => endConsultation(appt)}>End</button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      <div className="panel">
        <div className="panel-hd">
          <div className="panel-title">📋 Appointment Queue</div>
          <span className="count-badge">{upcoming.length} waiting</span>
        </div>
        {upcoming.length === 0 ? (
          <div className="empty-sm">
            <div style={{ fontSize: 32, marginBottom: 6 }}>✅</div>
            <p>Queue is clear for now</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {upcoming.map(appt => (
              <div key={appt.id} className="queue-card">
                <div className="queue-left">
                  <div className="queue-ava">{(appt.patientName || 'P')[0]}</div>
                  <div>
                    <div className="queue-name">{appt.patientName || 'Patient'}</div>
                    <div className="queue-specialty">{appt.specialty || 'Consultation'}</div>
                    <div className="queue-date">{fmtDate(appt.date)}</div>
                    {appt.patientNotes && (
                      <div className="queue-concern">💬 "{appt.patientNotes}"</div>
                    )}
                  </div>
                </div>
                <div className="queue-right">
                  <span className="payment-pill" style={{ background: appt.paymentStatus === 'paid' ? 'rgba(16,185,129,0.1)' : 'rgba(245,158,11,0.1)', color: appt.paymentStatus === 'paid' ? '#10b981' : '#f59e0b' }}>
                    {appt.paymentStatus === 'paid' ? '✓ Paid' : '⏳ Pending'}
                    {appt.amount ? ` · KES ${appt.amount?.toLocaleString()}` : ''}
                  </span>
                  <button
                    className="btn-start"
                    onClick={() => startConsultation(appt)}
                    disabled={starting === appt.id}
                  >
                    {starting === appt.id ? 'Starting…' : '▶ Start Session'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showRx && (
        <PrescriptionModal
          consultationId={showRx.cId}
          appointmentId={showRx.aId}
          existing={showRx.existing}
          onClose={() => setShowRx(null)}
          onSaved={() => {}}
        />
      )}
      {showNotes && (
        <NotesModal
          consultationId={showNotes.cId}
          appointmentId={showNotes.aId}
          currentNotes={showNotes.notes}
          onClose={() => setShowNotes(null)}
          onSaved={() => {}}
        />
      )}
    </div>
  );
}

// --- Patients Panel ------------------------------------------------------------
function PatientsPanel({ doctorId, appointments }: { doctorId: string; appointments: Appointment[] }) {
  const [patients, setPatients] = useState<PatientRecord[]>([]);
  const [selected, setSelected] = useState<PatientRecord | null>(null);
  const [search, setSearch]     = useState('');

  useEffect(() => {
    const ids = [...new Set(appointments.map(a => a.patientId))];
    if (!ids.length) return;
    Promise.all(ids.map(id => getDoc(doc(db, 'users', id)))).then(snaps => {
      setPatients(snaps.filter(s => s.exists()).map(s => ({ uid: s.id, ...s.data() } as PatientRecord)));
    });
  }, [appointments]);

  const filtered = patients.filter(p =>
    !search || `${p.name} ${p.email} ${p.condition}`.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="panel">
      <div className="panel-hd">
        <div className="panel-title">👥 My Patients</div>
        <span className="count-badge">{patients.length} total</span>
      </div>
      <div style={{ position: 'relative', marginBottom: 14 }}>
        <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', fontSize: 14, pointerEvents: 'none' }}>🔍</span>
        <input className="search-inp" style={{ paddingLeft: 36 }} value={search}
          onChange={e => setSearch(e.target.value)} placeholder="Search patients…" />
      </div>
      {filtered.length === 0 ? (
        <div className="empty-sm">
          <div style={{ fontSize: 32, marginBottom: 6 }}>👥</div>
          <p>{search ? 'No patients match your search' : 'No patients yet. Appointments will populate this list.'}</p>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 10 }}>
          {filtered.map(p => {
            const patientAppts = appointments.filter(a => a.patientId === p.uid);
            const last = patientAppts[0];
            return (
              <div key={p.uid} className="patient-card" onClick={() => setSelected(p)}>
                <div className="pc-top">
                  <div className="pc-ava">{p.name[0]}</div>
                  <div>
                    <div className="pc-name">{p.name}</div>
                    <div className="pc-email">{p.email}</div>
                  </div>
                </div>
                <div className="pc-chips">
                  {p.bloodGroup && <span className="pc-chip blood">{p.bloodGroup}</span>}
                  {p.condition  && <span className="pc-chip cond">{p.condition}</span>}
                  {p.age        && <span className="pc-chip">{p.age}y</span>}
                </div>
                {last && (
                  <div className="pc-last">
                    Last: {fmtShort(last.date)} · <span style={{ color: statusConfig[last.status]?.color }}>{statusConfig[last.status]?.label}</span>
                  </div>
                )}
                <div className="pc-count">{patientAppts.length} visit{patientAppts.length !== 1 ? 's' : ''}</div>
              </div>
            );
          })}
        </div>
      )}

      {selected && (
        <PatientDetailModal patient={selected} doctorId={doctorId} onClose={() => setSelected(null)} />
      )}
    </div>
  );
}

// --- History Panel -------------------------------------------------------------
function HistoryPanel({ appointments }: { appointments: Appointment[] }) {
  const [filter, setFilter] = useState<'all' | 'completed' | 'cancelled'>('all');
  const [showRx, setShowRx] = useState<Appointment | null>(null);
  const filtered = appointments.filter(a => filter === 'all' ? a.status !== 'active' && a.status !== 'booked' : a.status === filter);

  return (
    <div className="panel">
      <div className="panel-hd">
        <div className="panel-title">📋 Appointment History</div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['all', 'completed', 'cancelled'] as const).map(f => (
            <button key={f} className={`filter-chip ${filter === f ? 'active' : ''}`} onClick={() => setFilter(f)}>
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>
      {filtered.length === 0 ? (
        <div className="empty-sm">No {filter !== 'all' ? filter : ''} appointments yet.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {filtered.map(appt => {
            const sc = statusConfig[appt.status] || statusConfig.booked;
            return (
              <div key={appt.id} className="appt-card">
                <div className="appt-left">
                  <div className="appt-icon-box">
                    {appt.status === 'completed' ? '✅' : appt.status === 'cancelled' ? '❌' : '📅'}
                  </div>
                  <div>
                    <div className="appt-spec">{appt.patientName || 'Patient'}</div>
                    <div className="appt-dr">{appt.specialty || 'Consultation'}</div>
                    <div className="appt-date">{fmtDate(appt.date)}</div>
                    {appt.patientNotes && <div style={{ fontSize: 11, color: 'var(--muted)', fontStyle: 'italic', marginTop: 2 }}>"{appt.patientNotes}"</div>}
                  </div>
                </div>
                <div className="appt-right">
                  {appt.amount && (
                    <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--green)', fontFamily: 'var(--mono)' }}>
                      KES {appt.amount.toLocaleString()}
                    </span>
                  )}
                  <span className="status-pill" style={{ background: sc.bg, color: sc.color }}>{sc.label}</span>
                  {appt.status === 'completed' && (
                    <button className="btn-records" onClick={() => setShowRx(appt)}>📄 Records</button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {showRx && (
        <div className="overlay" onClick={() => setShowRx(null)}>
          <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>
            <div className="modal-hd">
              <div>
                <h3 className="modal-ht">Consultation Records</h3>
                <p className="modal-hs">{showRx.patientName} · {fmtDate(showRx.date)}</p>
              </div>
              <button className="modal-close" onClick={() => setShowRx(null)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="patient-detail-section">
                <div className="pd-section-title">📝 Clinical Notes</div>
                {showRx.notes ? <p className="rec-text">{showRx.notes}</p> : <p className="rec-empty">No notes.</p>}
              </div>
              <div className="patient-detail-section">
                <div className="pd-section-title">💊 Prescriptions ({showRx.prescriptions?.length || 0})</div>
                {showRx.prescriptions?.length ? (
                  showRx.prescriptions.map((rx, i) => (
                    <div key={i} className="rx-row" style={{ marginBottom: 6 }}>
                      <span className="rx-name">💊 {rx.medication}</span>
                      <span className="rx-detail">{rx.dosage} · {rx.frequency} · {rx.duration}</span>
                    </div>
                  ))
                ) : <p className="rec-empty">No prescriptions.</p>}
              </div>
              <button className="btn-secondary" onClick={() => setShowRx(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// --- Earnings Panel ------------------------------------------------------------
function EarningsPanel({ appointments }: { appointments: Appointment[] }) {
  const paid     = appointments.filter(a => a.paymentStatus === 'paid');
  const total    = paid.reduce((s, a) => s + (a.amount || 0), 0);
  const thisMonth = paid.filter(a => {
    const d = a.date?.toDate ? a.date.toDate() : new Date(a.date);
    const now = new Date();
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  }).reduce((s, a) => s + (a.amount || 0), 0);

  const byMonth: Record<string, number> = {};
  paid.forEach(a => {
    const d = a.date?.toDate ? a.date.toDate() : new Date(a.date);
    const key = d.toLocaleDateString('en-KE', { month: 'short', year: 'numeric' });
    byMonth[key] = (byMonth[key] || 0) + (a.amount || 0);
  });
  const months = Object.entries(byMonth).slice(-6);
  const maxVal = Math.max(...months.map(([, v]) => v), 1);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
        {[
          { icon: '💰', label: 'Total Earned', val: `KES ${total.toLocaleString()}`, color: 'var(--green)' },
          { icon: '📅', label: 'This Month',   val: `KES ${thisMonth.toLocaleString()}`, color: 'var(--accent)' },
          { icon: '🔢', label: 'Paid Sessions', val: paid.length.toString(), color: 'var(--amber)' },
        ].map(s => (
          <div key={s.label} className="stat-card">
            <span className="stat-icon">{s.icon}</span>
            <div>
              <div className="stat-val" style={{ color: s.color }}>{s.val}</div>
              <div className="stat-lbl">{s.label}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="panel">
        <div className="panel-hd">
          <div className="panel-title">📊 Revenue by Month</div>
        </div>
        {months.length === 0 ? (
          <div className="empty-sm">No revenue data yet.</div>
        ) : (
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', height: 120, padding: '0 4px' }}>
            {months.map(([m, v]) => (
              <div key={m} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, height: '100%' }}>
                <div style={{ fontSize: 9, color: 'var(--muted)', fontFamily: 'var(--mono)', whiteSpace: 'nowrap' }}>
                  {v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}
                </div>
                <div style={{ width: '100%', flex: 1, display: 'flex', alignItems: 'flex-end' }}>
                  <div style={{ width: '100%', background: 'linear-gradient(180deg, var(--accent), rgba(99,102,241,0.4))', borderRadius: '6px 6px 0 0', height: `${(v / maxVal) * 90}%`, minHeight: 4, transition: 'height 0.6s ease' }} />
                </div>
                <div style={{ fontSize: 9, color: 'var(--muted)', whiteSpace: 'nowrap' }}>{m}</div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="panel">
        <div className="panel-hd"><div className="panel-title">🧾 Transactions</div></div>
        {paid.length === 0 ? (
          <div className="empty-sm">No transactions yet.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {paid.slice(0, 10).map(a => (
              <div key={a.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 12px', background: 'var(--bg)', borderRadius: 10, border: '1px solid var(--border)' }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700 }}>{a.patientName || 'Patient'}</div>
                  <div style={{ fontSize: 11, color: 'var(--muted)', fontFamily: 'var(--mono)' }}>{fmtDate(a.date)}</div>
                </div>
                <span style={{ fontWeight: 800, fontSize: 14, color: 'var(--green)', fontFamily: 'var(--mono)' }}>
                  + KES {(a.amount || 0).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// --- Services Panel ------------------------------------------------------------
function ServicesPanel({ doctor, services }: { doctor: DoctorProfile; services: Service[] }) {
  const [showCreate, setShowCreate] = useState(false);
  const [editing, setEditing]       = useState<Service | null>(null);

  const toggle = async (svc: Service) =>
    await updateDoc(doc(db, 'services', svc.id), { isAvailable: !svc.isAvailable });

  const remove = async (svc: Service) => {
    if (!confirm(`Delete "${svc.specialty}" service?`)) return;
    await deleteDoc(doc(db, 'services', svc.id));
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div className="panel">
        <div className="panel-hd">
          <div className="panel-title">🏥 My Services</div>
          <button className="btn-sm-accent" onClick={() => setShowCreate(true)}>+ New Service</button>
        </div>
        <p style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 14 }}>
          {services.filter(s => s.isAvailable).length} of {services.length} services are visible to patients.
        </p>
        {services.length === 0 ? (
          <div className="empty-sm">
            <div style={{ fontSize: 40, marginBottom: 10 }}>🏥</div>
            <p>No services yet. Create one and patients can find and book you.</p>
            <button className="btn-sm-accent" style={{ marginTop: 14 }} onClick={() => setShowCreate(true)}>+ Create First Service</button>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 12 }}>
            {services.map(svc => (
              <div key={svc.id} className={`svc-manage-card ${!svc.isAvailable ? 'svc-paused' : ''}`}>
                <div className="svc-mc-hd">
                  <div className="svc-mc-title">{svc.specialty}</div>
                  <button className={`avail-toggle ${svc.isAvailable ? 'on' : 'off'}`} onClick={() => toggle(svc)}>
                    {svc.isAvailable ? '● Live' : 'Paused'}
                  </button>
                </div>
                <div className="svc-mc-price">KES {svc.price?.toLocaleString()}</div>
                <div className="svc-mc-meta">
                  <span>🏥 {svc.clinic}</span>
                  <span>⏱ {svc.duration} min</span>
                  {svc.location && <span>📍 {svc.location}</span>}
                </div>
                {svc.tags?.length ? (
                  <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
                    {svc.tags.map(t => <span key={t} className="svc-tag">{t}</span>)}
                  </div>
                ) : null}
                {svc.description && <p className="svc-desc-text">{svc.description}</p>}
                <div className="svc-mc-actions">
                  <button className="btn-edit" onClick={() => setEditing(svc)}>✏️ Edit</button>
                  <button className="btn-delete" onClick={() => remove(svc)}>🗑️ Delete</button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {(showCreate || editing) && (
        <ServiceModal
          doctor={doctor}
          existing={editing || undefined}
          onClose={() => { setShowCreate(false); setEditing(null); }}
        />
      )}
    </div>
  );
}

// --- Settings Panel ------------------------------------------------------------
function SettingsPanel({ doctor, onUpdated }: { doctor: DoctorProfile; onUpdated: () => void }) {
  const [form, setForm] = useState({
    name:            doctor.name || '',
    specialty:       doctor.specialty || '',
    clinic:          doctor.clinic || '',
    phone:           doctor.phone || '',
    licenseNumber:   doctor.licenseNumber || '',
    bio:             doctor.bio || '',
    location:        doctor.location || '',
    yearsExperience: doctor.yearsExperience?.toString() || '',
    languages:       doctor.languages?.join(', ') || '',
  });
  const [saving, setSaving] = useState(false);
  const [saved,  setSaved]  = useState(false);

  const f = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setForm(p => ({ ...p, [k]: e.target.value }));

  const save = async () => {
    setSaving(true);
    await updateDoc(doc(db, 'users', doctor.uid), {
      ...form,
      yearsExperience: form.yearsExperience ? Number(form.yearsExperience) : null,
      languages: form.languages.split(',').map(l => l.trim()).filter(Boolean),
    });
    setSaved(true); setTimeout(() => setSaved(false), 2500);
    onUpdated();
    setSaving(false);
  };

  return (
    <div className="panel" style={{ maxWidth: 700 }}>
      <div className="panel-hd">
        <div className="panel-title">⚙️ Profile Settings</div>
        {saved && <span style={{ color: 'var(--green)', fontSize: 13, fontWeight: 700 }}>✓ Saved</span>}
      </div>
      <div className="form-grid-2" style={{ gap: 14 }}>
        {[
          { k: 'name',            label: 'Full Name',           ph: 'Dr. Jane Mwangi' },
          { k: 'specialty',       label: 'Specialty',           ph: 'e.g. Cardiology' },
          { k: 'clinic',          label: 'Clinic',              ph: 'e.g. Nairobi Heart Centre' },
          { k: 'phone',           label: 'Phone',               ph: '+254 7xx xxx xxx' },
          { k: 'licenseNumber',   label: 'Medical License No.', ph: 'e.g. ML-12345' },
          { k: 'location',        label: 'Location',            ph: 'e.g. Nairobi, Kenya' },
          { k: 'yearsExperience', label: 'Years Experience',    ph: 'e.g. 12' },
          { k: 'languages',       label: 'Languages (comma-separated)', ph: 'English, Swahili' },
        ].map(field => (
          <div key={field.k} className="field-col">
            <label className="field-lbl">{field.label}</label>
            <input className="field-inp" value={(form as any)[field.k]} onChange={f(field.k)} placeholder={field.ph} />
          </div>
        ))}
        <div className="field-col form-full">
          <label className="field-lbl">Bio / Professional Summary</label>
          <textarea className="field-ta" rows={4} value={form.bio} onChange={f('bio')} placeholder="Tell patients about your experience and approach…" />
        </div>
      </div>
      <button className="btn-cta" onClick={save} disabled={saving} style={{ marginTop: 16, maxWidth: 220 }}>
        {saving ? 'Saving…' : '💾 Save Profile'}
      </button>
    </div>
  );
}

// --- Disease Tools Panel -------------------------------------------------------
function DiseaseToolsPanel({ patients }: { patients: PatientRecord[] }) {
  const conditions = ['All', ...Array.from(new Set(patients.map(p => p.condition).filter(Boolean)))];
  const [condition, setCondition] = useState('All');

  const tools: Record<string, Array<{ icon: string; label: string; desc: string; color: string }>> = {
    Hypertension: [
      { icon: '📊', label: 'BP Trend Dashboard',    desc: 'View population-level BP trends across your hypertension patients', color: '#dc2626' },
      { icon: '🔔', label: 'High BP Alert Rules',   desc: 'Auto-alert when patient BP exceeds threshold',                      color: '#f59e0b' },
      { icon: '💊', label: 'Medication Compliance', desc: 'Track adherence to antihypertensives',                              color: '#2563eb' },
      { icon: '📋', label: 'JNC Protocol Checker',  desc: 'Validate treatment against guidelines',                             color: '#7c3aed' },
    ],
    Diabetes: [
      { icon: '🩸', label: 'Glucose Monitor',    desc: 'Track HbA1c and daily readings per patient',   color: '#d97706' },
      { icon: '📈', label: 'HbA1c Tracker',      desc: 'Long-term glycaemic control charts',            color: '#2563eb' },
      { icon: '💉', label: 'Insulin Log Review', desc: 'Review patient insulin logs and adjust doses',  color: '#7c3aed' },
      { icon: '🍱', label: 'Diet Compliance',    desc: 'Review patient carb and meal logs',             color: '#22c55e' },
    ],
    Asthma: [
      { icon: '🌬️', label: 'Peak Flow Monitor',  desc: 'Track peak flow readings and trends',                         color: '#2563eb' },
      { icon: '📓', label: 'Trigger Analysis',   desc: 'Identify and map common triggers per patient',                color: '#f59e0b' },
      { icon: '💊', label: 'Inhaler Adherence',  desc: 'Monitor whether patients are using preventers',              color: '#dc2626' },
      { icon: '🌍', label: 'Air Quality Alerts', desc: 'Notify high-risk patients on bad air days',                  color: '#059669' },
    ],
  };

  const currentTools = condition !== 'All'
    ? (tools[condition] ?? [])
    : Object.values(tools).flat().slice(0, 6);

  return (
    <div style={{ background: 'white', borderRadius: 18, border: '1.5px solid #e2e8f0', padding: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h3 style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>🛠️ Disease Management Tools</h3>
        <select value={condition} onChange={e => setCondition(e.target.value)}
          style={{ padding: '6px 12px', borderRadius: 10, border: '1.5px solid #e2e8f0', fontSize: 13, background: 'white', cursor: 'pointer' }}>
          {conditions.map(c => <option key={c}>{c}</option>)}
        </select>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 10 }}>
        {currentTools.map(t => (
          <button
            key={t.label}
            style={{ background: '#f8fafc', border: '1.5px solid #e2e8f0', borderRadius: 14, padding: '14px', cursor: 'pointer', textAlign: 'left', transition: 'all 0.15s' }}
            onMouseEnter={e => { (e.currentTarget as HTMLElement).style.borderColor = t.color; (e.currentTarget as HTMLElement).style.background = '#eff6ff'; }}
            onMouseLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = '#e2e8f0'; (e.currentTarget as HTMLElement).style.background = '#f8fafc'; }}
          >
            <div style={{ fontSize: 22, marginBottom: 8 }}>{t.icon}</div>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#0f172a', marginBottom: 4 }}>{t.label}</div>
            <div style={{ fontSize: 11, color: '#64748b', lineHeight: 1.4 }}>{t.desc}</div>
          </button>
        ))}
      </div>
    </div>
  );
}

// -----------------------------------------------------------------------------
// MAIN DOCTOR DASHBOARD
// -----------------------------------------------------------------------------
export default function DoctorDashboard() {
  const router = useRouter();
  const [authDone, setAuthDone]         = useState(false);
  const [doctor,   setDoctor]           = useState<DoctorProfile | null>(null);
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [services,     setServices]     = useState<Service[]>([]);
  const [activeTab, setActiveTab]       = useState<'overview'|'queue'|'patients'|'history'|'messages'|'services'|'earnings'|'settings'|'tools'>('overview');

  // Auth
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async user => {
      if (!user) { router.replace('/login'); return; }
      const snap = await getDoc(doc(db, 'users', user.uid));
      const data = snap.data() || {};
      if (data.role !== 'doctor') { router.replace('/dashboard/patient'); return; }
      setDoctor({
        uid:             user.uid,
        name:            data.name || user.displayName || 'Doctor',
        email:           data.email || user.email || '',
        specialty:       data.specialty || '',
        clinic:          data.clinic,
        licenseNumber:   data.licenseNumber,
        phone:           data.phone,
        bio:             data.bio,
        yearsExperience: data.yearsExperience,
        languages:       data.languages,
        location:        data.location,
      });
      setAuthDone(true);
    });
    return () => unsub();
  }, [router]);

  // Appointments listener
  useEffect(() => {
    if (!doctor) return;
    const unsub = onSnapshot(
      query(collection(db, 'appointments'), where('doctorId', '==', doctor.uid), orderBy('date', 'desc')),
      async snap => {
        const appts = await Promise.all(snap.docs.map(async d => {
          const a = { id: d.id, ...d.data() } as Appointment;
          if (a.patientId && !a.patientName) {
            try {
              const ps = await getDoc(doc(db, 'users', a.patientId));
              if (ps.exists()) {
                a.patientName  = ps.data().name;
                a.patientEmail = ps.data().email;
                a.patientPhone = ps.data().phone;
              }
            } catch {}
          }
          return a;
        }));
        setAppointments(appts);
      }
    );
    return () => unsub();
  }, [doctor]);

  // Services listener
  useEffect(() => {
    if (!doctor) return;
    const unsub = onSnapshot(
      query(collection(db, 'services'), where('doctorId', '==', doctor.uid), orderBy('createdAt', 'desc')),
      snap => setServices(snap.docs.map(d => ({ id: d.id, ...d.data() } as Service)))
    );
    return () => unsub();
  }, [doctor]);

  // Derived stats
  const todayAppts     = appointments.filter(a => isToday(a.date));
  const activeAppts    = appointments.filter(a => a.status === 'active');
  const upcomingAppts  = appointments.filter(a => a.status === 'booked');
  const completedAppts = appointments.filter(a => a.status === 'completed');
  const totalEarned    = appointments.filter(a => a.paymentStatus === 'paid').reduce((s, a) => s + (a.amount || 0), 0);
  const patientIds     = [...new Set(appointments.map(a => a.patientId))];

  const tabs = [
    { id: 'overview',  icon: '🏠',  label: 'Overview' },
    { id: 'queue',     icon: '📋',  label: 'Queue',    badge: upcomingAppts.length + activeAppts.length },
    { id: 'patients',  icon: '👥',  label: 'Patients' },
    { id: 'history',   icon: '🗂️', label: 'History' },
    { id: 'messages',  icon: '💬',  label: 'Messages' },
    { id: 'tools',     icon: '🛠️',  label: 'Tools' },
    { id: 'services',  icon: '🏥',  label: 'Services' },
    { id: 'earnings',  icon: '💰',  label: 'Earnings' },
    { id: 'settings',  icon: '⚙️', label: 'Settings' },
  ];

  if (!authDone || !doctor) {
    return (
      <div style={{ minHeight: '100vh', background: '#f4f6fb', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: 48, height: 48, border: '3px solid #e2e8f0', borderTopColor: '#10b981', borderRadius: '50%', animation: 'spin .7s linear infinite', margin: '0 auto 16px' }} />
          <p style={{ color: '#64748b' }}>Loading your dashboard…</p>
        </div>
        <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
      </div>
    );
  }

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&family=Fira+Code:wght@400;500&display=swap');

        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
          --bg: #f4f6fb;
          --white: #ffffff;
          --surface: #ffffff;
          --border: #e8ecf4;
          --text: #0f172a;
          --text-2: #475569;
          --muted: #94a3b8;
          --accent: #10b981;
          --accent-2: #34d399;
          --accent-dim: rgba(16,185,129,0.08);
          --green: #10b981;
          --green-dim: rgba(16,185,129,0.08);
          --amber: #f59e0b;
          --amber-dim: rgba(245,158,11,0.08);
          --red: #ef4444;
          --red-dim: rgba(239,68,68,0.08);
          --indigo: #6366f1;
          --indigo-dim: rgba(99,102,241,0.08);
          --font: 'Plus Jakarta Sans', sans-serif;
          --mono: 'Fira Code', monospace;
          --r: 16px;
          --r-sm: 10px;
          --shadow: 0 1px 3px rgba(0,0,0,0.05), 0 1px 2px rgba(0,0,0,0.04);
          --shadow-md: 0 4px 16px rgba(0,0,0,0.07);
          --shadow-lg: 0 12px 40px rgba(0,0,0,0.12);
        }

        body { background: var(--bg); color: var(--text); font-family: var(--font); -webkit-font-smoothing: antialiased; }
        @keyframes spin    { to { transform: rotate(360deg); } }
        @keyframes fadeUp  { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }
        @keyframes pulse-g { 0%,100%{box-shadow:0 0 0 0 rgba(16,185,129,0.4)} 50%{box-shadow:0 0 0 8px rgba(16,185,129,0)} }
        ::-webkit-scrollbar { width: 4px; height: 4px; }
        ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 99px; }

        /* Layout */
        .shell  { display: flex; min-height: 100vh; }
        .sidebar { width: 240px; background: var(--white); border-right: 1px solid var(--border); display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh; flex-shrink: 0; z-index: 30; }
        .main   { flex: 1; overflow-y: auto; padding-bottom: 80px; }

        /* Sidebar */
        .sb-brand { padding: 22px 20px 16px; border-bottom: 1px solid var(--border); }
        .sb-logo  { display: flex; align-items: center; gap: 9px; }
        .sb-icon  { width: 36px; height: 36px; border-radius: 10px; background: linear-gradient(135deg, #10b981, #06b6d4); display: flex; align-items: center; justify-content: center; font-size: 18px; box-shadow: 0 4px 12px rgba(16,185,129,0.3); }
        .sb-name  { font-size: 18px; font-weight: 900; letter-spacing: -0.5px; }
        .sb-sub   { font-size: 9px; color: var(--accent); font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; margin-top: 1px; }

        .sb-profile { padding: 16px 20px; border-bottom: 1px solid var(--border); }
        .sb-ava   { width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, #10b981, #06b6d4); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 18px; color: white; margin-bottom: 8px; }
        .sb-pname { font-weight: 700; font-size: 14px; }
        .sb-psub  { font-size: 11px; color: var(--accent); font-weight: 600; margin-top: 1px; }
        .sb-pemail { font-size: 11px; color: var(--muted); margin-top: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

        .sb-nav  { flex: 1; padding: 12px 10px; display: flex; flex-direction: column; gap: 2px; overflow-y: auto; }
        .sb-item { display: flex; align-items: center; gap: 9px; padding: 10px 12px; border-radius: var(--r-sm); border: none; background: transparent; color: var(--text-2); font-size: 13px; font-weight: 600; cursor: pointer; font-family: var(--font); width: 100%; text-align: left; transition: all 0.15s; position: relative; }
        .sb-item:hover { background: var(--bg); color: var(--text); }
        .sb-item.active { background: var(--accent-dim); color: var(--accent); }
        .sb-item-icon   { font-size: 16px; flex-shrink: 0; }
        .sb-badge { margin-left: auto; background: var(--red); color: white; border-radius: 99px; font-size: 10px; font-weight: 700; padding: 1px 6px; min-width: 18px; text-align: center; }

        .sb-footer   { padding: 12px 10px; border-top: 1px solid var(--border); }
        .sb-signout  { display: flex; align-items: center; gap: 8px; width: 100%; padding: 10px 12px; background: transparent; border: 1px solid var(--border); border-radius: var(--r-sm); color: var(--muted); font-size: 13px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .sb-signout:hover { border-color: var(--red); color: var(--red); background: var(--red-dim); }

        /* Top bar */
        .top-bar { background: var(--white); border-bottom: 1px solid var(--border); padding: 12px 28px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 20; box-shadow: var(--shadow); }
        .tb-left  { display: flex; flex-direction: column; }
        .tb-greet { font-size: 12px; color: var(--muted); font-weight: 500; }
        .tb-name  { font-size: 20px; font-weight: 800; letter-spacing: -0.3px; }
        .tb-right { display: flex; gap: 8px; align-items: center; }
        .tb-btn   { display: flex; align-items: center; gap: 6px; padding: 8px 14px; border-radius: var(--r-sm); border: 1px solid var(--border); background: var(--white); color: var(--text-2); font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .tb-btn:hover { border-color: var(--accent); color: var(--accent); background: var(--accent-dim); }
        .tb-btn-green { background: var(--accent); color: white; border-color: transparent; box-shadow: 0 4px 12px rgba(16,185,129,0.3); }
        .tb-btn-green:hover { background: #34d399; color: white; }

        /* Content */
        .content { padding: 24px 28px; animation: fadeUp 0.25s ease; max-width: 1400px; }

        /* Hero */
        .hero-card { background: linear-gradient(135deg, #0f172a 0%, #134e4a 50%, #0f766e 100%); border-radius: 20px; padding: 26px 30px; color: white; position: relative; overflow: hidden; margin-bottom: 20px; }
        .hero-card::before { content: ''; position: absolute; top: -40px; right: -40px; width: 200px; height: 200px; border-radius: 50%; background: rgba(16,185,129,0.1); pointer-events: none; }
        .hero-card::after  { content: ''; position: absolute; bottom: -50px; left: 30%; width: 160px; height: 160px; border-radius: 50%; background: rgba(255,255,255,0.04); pointer-events: none; }
        .hero-greet { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; opacity: 0.7; margin-bottom: 4px; }
        .hero-name  { font-size: 24px; font-weight: 900; letter-spacing: -0.5px; }
        .hero-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
        .hero-chip  { background: rgba(255,255,255,0.15); border-radius: 99px; padding: 3px 10px; font-size: 11px; font-weight: 700; backdrop-filter: blur(8px); }
        .hero-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-top: 20px; }
        .hero-stat  { background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 12px 14px; text-align: center; backdrop-filter: blur(8px); }
        .hero-stat-val   { font-size: 22px; font-weight: 900; font-family: var(--mono); }
        .hero-stat-label { font-size: 10px; opacity: 0.7; margin-top: 2px; font-weight: 600; }

        /* Stats */
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; }
        .stat-card  { background: var(--white); border: 1px solid var(--border); border-radius: var(--r); padding: 16px 18px; display: flex; align-items: center; gap: 12px; box-shadow: var(--shadow); transition: all 0.2s; }
        .stat-card:hover { border-color: var(--accent); box-shadow: var(--shadow-md); transform: translateY(-1px); }
        .stat-icon  { font-size: 28px; flex-shrink: 0; }
        .stat-val   { font-size: 24px; font-weight: 900; font-family: var(--mono); }
        .stat-lbl   { font-size: 11px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }

        /* Panels */
        .panel       { background: var(--white); border: 1px solid var(--border); border-radius: var(--r); padding: 18px 20px; box-shadow: var(--shadow); }
        .panel-hd    { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }
        .panel-title { font-size: 14px; font-weight: 800; display: flex; align-items: center; gap: 6px; }
        .count-badge { background: var(--accent-dim); color: var(--accent); border-radius: 99px; font-size: 11px; font-weight: 700; padding: 2px 8px; }
        .btn-sm-accent { background: var(--accent); color: white; border: none; border-radius: 8px; padding: 6px 12px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-sm-accent:hover { background: #34d399; }
        .empty-sm { text-align: center; padding: 28px 0; color: var(--muted); font-size: 13px; }

        /* Active session */
        .active-sessions-panel { border-color: rgba(16,185,129,0.4); background: rgba(16,185,129,0.03); }
        .live-dot-sm { width: 8px; height: 8px; border-radius: 50%; background: var(--green); display: inline-block; animation: pulse-g 1.5s infinite; margin-right: 4px; }
        .active-session-card { background: rgba(16,185,129,0.06); border: 1.5px solid rgba(16,185,129,0.25); border-radius: 14px; padding: 14px 16px; display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; }
        .as-left { display: flex; align-items: center; gap: 10px; }
        .as-ava  { width: 42px; height: 42px; border-radius: 11px; background: linear-gradient(135deg, #10b981, #06b6d4); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 17px; color: white; flex-shrink: 0; }
        .as-name { font-weight: 700; font-size: 14px; }
        .as-sub  { font-size: 12px; color: var(--muted); margin-top: 2px; }
        .as-concern { font-size: 11px; color: var(--text-2); font-style: italic; margin-top: 3px; max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .as-actions { display: flex; gap: 8px; flex-wrap: wrap; }
        .btn-action { background: var(--white); border: 1px solid var(--border); border-radius: 8px; padding: 7px 12px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-action:hover { border-color: var(--accent); color: var(--accent); }
        .btn-join-live { background: var(--green); color: #000; border: none; border-radius: 8px; padding: 8px 14px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-join-live:hover { background: #34d399; }
        .btn-end { background: var(--red-dim); color: var(--red); border: 1px solid rgba(239,68,68,0.25); border-radius: 8px; padding: 7px 12px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-end:hover { background: var(--red); color: white; }

        /* Queue cards */
        .queue-card { background: var(--bg); border: 1.5px solid var(--border); border-radius: 14px; padding: 14px 16px; display: flex; justify-content: space-between; align-items: flex-start; gap: 14px; flex-wrap: wrap; transition: border-color 0.2s; }
        .queue-card:hover { border-color: var(--accent); }
        .queue-left { display: flex; align-items: flex-start; gap: 10px; }
        .queue-ava  { width: 40px; height: 40px; border-radius: 10px; background: linear-gradient(135deg, #6366f1, #8b5cf6); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 16px; color: white; flex-shrink: 0; }
        .queue-name { font-weight: 700; font-size: 14px; }
        .queue-specialty { font-size: 12px; color: var(--text-2); margin-top: 2px; }
        .queue-date { font-size: 11px; color: var(--muted); font-family: var(--mono); margin-top: 2px; }
        .queue-concern { font-size: 11px; color: var(--text-2); font-style: italic; margin-top: 4px; }
        .queue-right { display: flex; flex-direction: column; align-items: flex-end; gap: 8px; }
        .payment-pill { font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 99px; }
        .btn-start { background: linear-gradient(135deg, #10b981, #06b6d4); color: white; border: none; border-radius: 10px; padding: 10px 18px; font-size: 13px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; box-shadow: 0 4px 12px rgba(16,185,129,0.3); }
        .btn-start:hover { box-shadow: 0 6px 20px rgba(16,185,129,0.45); }
        .btn-start:disabled { opacity: 0.5; cursor: not-allowed; }

        /* Appointment cards */
        .appt-card  { background: var(--white); border: 1.5px solid var(--border); border-radius: var(--r); padding: 14px 18px; display: flex; justify-content: space-between; align-items: center; gap: 14px; transition: border-color 0.2s; }
        .appt-card:hover { border-color: var(--accent); }
        .appt-left  { display: flex; align-items: center; gap: 10px; }
        .appt-icon-box { width: 42px; height: 42px; border-radius: 11px; background: var(--bg); display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; }
        .appt-spec  { font-weight: 700; font-size: 14px; }
        .appt-dr    { font-size: 12px; color: var(--text-2); margin-top: 2px; }
        .appt-date  { font-size: 11px; color: var(--muted); font-family: var(--mono); margin-top: 2px; }
        .appt-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
        .status-pill { display: inline-flex; align-items: center; padding: 4px 10px; border-radius: 99px; font-size: 11px; font-weight: 700; }
        .btn-records { background: transparent; border: 1px solid var(--border); color: var(--text-2); border-radius: 8px; padding: 7px 12px; font-size: 12px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-records:hover { border-color: var(--accent); color: var(--accent); }

        /* Filter chips */
        .filter-chip { padding: 6px 14px; border-radius: 99px; border: 1.5px solid var(--border); background: var(--white); color: var(--text-2); font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .filter-chip.active { background: var(--accent); border-color: var(--accent); color: white; }
        .filter-chip:not(.active):hover { border-color: var(--accent); color: var(--accent); }

        /* Patient cards */
        .patient-card { background: var(--white); border: 1.5px solid var(--border); border-radius: 16px; padding: 16px; cursor: pointer; transition: all 0.2s; display: flex; flex-direction: column; gap: 10px; }
        .patient-card:hover { border-color: var(--accent); transform: translateY(-2px); box-shadow: var(--shadow-md); }
        .pc-top   { display: flex; align-items: center; gap: 10px; }
        .pc-ava   { width: 42px; height: 42px; border-radius: 11px; background: linear-gradient(135deg, #6366f1, #06b6d4); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 17px; color: white; flex-shrink: 0; }
        .pc-name  { font-weight: 700; font-size: 14px; }
        .pc-email { font-size: 11px; color: var(--muted); margin-top: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 160px; }
        .pc-chips { display: flex; gap: 5px; flex-wrap: wrap; }
        .pc-chip  { font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 99px; background: var(--bg); color: var(--text-2); border: 1px solid var(--border); }
        .pc-chip.blood { background: rgba(239,68,68,0.08); color: var(--red); border-color: rgba(239,68,68,0.2); }
        .pc-chip.cond  { background: var(--accent-dim); color: var(--accent); border-color: rgba(16,185,129,0.2); }
        .pc-last  { font-size: 11px; color: var(--muted); }
        .pc-count { font-size: 11px; font-weight: 700; color: var(--accent); }

        /* Patient detail modal */
        .info-chip { background: var(--bg); border: 1px solid var(--border); border-radius: 99px; padding: 3px 10px; font-size: 12px; font-weight: 700; }
        .allergy-box { background: var(--red-dim); border: 1px solid rgba(239,68,68,0.25); border-radius: 10px; padding: 9px 12px; font-size: 12px; font-weight: 700; color: var(--red); }
        .patient-detail-section { display: flex; flex-direction: column; gap: 8px; }
        .pd-section-title { font-size: 13px; font-weight: 800; padding-bottom: 8px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 5px; }
        .vitals-summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
        .vs-card  { background: var(--bg); border-radius: 10px; padding: 10px 8px; display: flex; flex-direction: column; align-items: center; text-align: center; gap: 2px; }
        .vs-icon  { font-size: 20px; }
        .vs-val   { font-size: 16px; font-weight: 900; font-family: var(--mono); }
        .vs-label { font-size: 10px; color: var(--muted); font-weight: 600; }
        .vs-sub   { font-size: 10px; font-weight: 700; }
        .rec-text  { font-size: 13px; color: var(--text-2); line-height: 1.7; background: var(--bg); border-radius: var(--r-sm); padding: 12px; }
        .rec-empty { font-size: 13px; color: var(--muted); font-style: italic; }
        .rx-row    { display: flex; justify-content: space-between; align-items: center; padding: 8px 10px; background: var(--bg); border-radius: 8px; gap: 8px; }
        .rx-name   { font-size: 13px; font-weight: 700; }
        .rx-detail { font-size: 11px; color: var(--muted); }

        /* Services */
        .svc-manage-card { background: var(--white); border: 1.5px solid var(--border); border-radius: 16px; padding: 18px; display: flex; flex-direction: column; gap: 10px; transition: all 0.2s; }
        .svc-manage-card:hover { border-color: var(--accent); box-shadow: var(--shadow-md); }
        .svc-paused { opacity: 0.55; }
        .svc-mc-hd  { display: flex; justify-content: space-between; align-items: center; }
        .svc-mc-title { font-weight: 800; font-size: 16px; }
        .avail-toggle { padding: 4px 10px; border-radius: 99px; font-size: 11px; font-weight: 700; cursor: pointer; border: none; font-family: var(--font); transition: all 0.15s; }
        .avail-toggle.on  { background: var(--green-dim); color: var(--green); }
        .avail-toggle.off { background: var(--red-dim);   color: var(--red); }
        .svc-mc-price { font-size: 22px; font-weight: 900; color: var(--accent); font-family: var(--mono); }
        .svc-mc-meta  { display: flex; gap: 10px; flex-wrap: wrap; font-size: 12px; color: var(--text-2); }
        .svc-tag      { background: var(--indigo-dim); color: var(--indigo); border-radius: 99px; padding: 2px 8px; font-size: 11px; font-weight: 700; }
        .svc-desc-text { font-size: 12px; color: var(--muted); line-height: 1.6; }
        .svc-mc-actions { display: flex; gap: 8px; margin-top: 4px; }
        .btn-edit   { background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 6px 12px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-edit:hover { border-color: var(--accent); color: var(--accent); }
        .btn-delete { background: var(--red-dim); border: 1px solid rgba(239,68,68,0.2); color: var(--red); border-radius: 8px; padding: 6px 12px; font-size: 12px; font-weight: 700; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .btn-delete:hover { background: var(--red); color: white; }

        /* Chat */
        .chat-shell   { display: grid; grid-template-columns: 260px 1fr; background: var(--white); border: 1px solid var(--border); border-radius: var(--r); overflow: hidden; min-height: 520px; box-shadow: var(--shadow); }
        .chat-sidebar { border-right: 1px solid var(--border); overflow-y: auto; display: flex; flex-direction: column; }
        .chat-sidebar-hd { padding: 16px 16px 12px; border-bottom: 1px solid var(--border); font-size: 14px; font-weight: 800; }
        .chat-patient-btn { display: flex; align-items: center; gap: 10px; width: 100%; padding: 12px 14px; border: none; background: transparent; cursor: pointer; text-align: left; transition: background 0.12s; border-bottom: 1px solid var(--border); }
        .chat-patient-btn:hover { background: var(--bg); }
        .chat-patient-btn.active { background: var(--accent-dim); }
        .chat-patient-ava  { width: 36px; height: 36px; border-radius: 9px; background: linear-gradient(135deg, #10b981, #06b6d4); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 14px; color: white; flex-shrink: 0; }
        .chat-patient-info { display: flex; flex-direction: column; overflow: hidden; }
        .chat-patient-name { font-size: 13px; font-weight: 700; color: var(--text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .chat-patient-sub  { font-size: 11px; color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .chat-area    { display: flex; flex-direction: column; }
        .chat-area-hd { padding: 13px 18px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 10px; background: var(--bg); }
        .chat-empty   { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--muted); text-align: center; }
        .chat-feed    { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 14px 18px; max-height: 380px; }
        .msg-bubble-wrap { display: flex; }
        .msg-bubble-wrap.mine   { justify-content: flex-end; }
        .msg-bubble-wrap.theirs { justify-content: flex-start; }
        .msg-bubble   { max-width: 80%; padding: 9px 13px; border-radius: 13px; font-size: 13px; line-height: 1.5; }
        .msg-mine     { background: linear-gradient(135deg, #10b981, #06b6d4); color: white; border-bottom-right-radius: 4px; }
        .msg-theirs   { background: var(--bg); color: var(--text); border: 1px solid var(--border); border-bottom-left-radius: 4px; }
        .msg-sender   { font-size: 9px; font-weight: 800; opacity: 0.7; margin-bottom: 3px; text-transform: uppercase; letter-spacing: 0.5px; }
        .chat-input-row { display: flex; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--border); }
        .chat-inp     { flex: 1; background: var(--bg); border: 1.5px solid var(--border); border-radius: var(--r-sm); padding: 10px 13px; color: var(--text); font-size: 13px; font-family: var(--font); outline: none; }
        .chat-inp:focus { border-color: var(--accent); }
        .chat-send    { background: var(--accent); border: none; color: white; padding: 10px 16px; border-radius: var(--r-sm); font-weight: 700; cursor: pointer; font-size: 16px; transition: all 0.15s; }
        .chat-send:hover { background: #34d399; }

        /* Modals */
        .overlay   { position: fixed; inset: 0; background: rgba(0,0,0,0.45); z-index: 100; display: flex; align-items: center; justify-content: center; padding: 16px; backdrop-filter: blur(6px); }
        .modal-box { background: var(--white); border: 1px solid var(--border); border-radius: 22px; width: 100%; max-height: 92vh; overflow-y: auto; box-shadow: var(--shadow-lg); animation: fadeUp 0.2s ease; }
        .modal-hd  { padding: 22px 22px 0; display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 18px; }
        .modal-ht  { font-size: 18px; font-weight: 800; }
        .modal-hs  { font-size: 12px; color: var(--muted); margin-top: 3px; }
        .modal-close { background: var(--bg); border: none; color: var(--text-2); width: 30px; height: 30px; border-radius: 8px; cursor: pointer; font-size: 14px; flex-shrink: 0; }
        .modal-body { padding: 0 22px 22px; display: flex; flex-direction: column; gap: 14px; }

        /* Forms */
        .form-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
        .form-full   { grid-column: 1 / -1; }
        .field-col   { display: flex; flex-direction: column; gap: 5px; }
        .field-lbl   { font-size: 10px; font-weight: 800; color: var(--muted); text-transform: uppercase; letter-spacing: 0.8px; }
        .field-inp   { background: var(--bg); border: 1.5px solid var(--border); border-radius: var(--r-sm); padding: 11px 13px; color: var(--text); font-size: 14px; font-family: var(--font); outline: none; transition: border-color 0.15s; width: 100%; }
        .field-inp:focus { border-color: var(--accent); }
        .field-ta    { background: var(--bg); border: 1.5px solid var(--border); border-radius: var(--r-sm); padding: 11px 13px; color: var(--text); font-size: 14px; font-family: var(--font); outline: none; transition: border-color 0.15s; width: 100%; resize: vertical; }
        .field-ta:focus { border-color: var(--accent); }
        .err-box     { background: var(--red-dim); border: 1px solid rgba(239,68,68,0.3); border-radius: var(--r-sm); padding: 8px 12px; font-size: 12px; color: var(--red); border-left: 3px solid var(--red); }
        .btn-cta     { background: linear-gradient(135deg, #10b981, #06b6d4); color: white; border: none; border-radius: 12px; padding: 13px; font-size: 14px; font-weight: 700; cursor: pointer; font-family: var(--font); width: 100%; transition: all 0.15s; box-shadow: 0 4px 16px rgba(16,185,129,0.3); }
        .btn-cta:hover { box-shadow: 0 6px 24px rgba(16,185,129,0.45); }
        .btn-cta:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-secondary { background: transparent; border: 1.5px solid var(--border); color: var(--text-2); border-radius: 12px; padding: 11px; font-size: 13px; font-weight: 600; cursor: pointer; font-family: var(--font); width: 100%; transition: all 0.15s; }
        .btn-secondary:hover { border-color: var(--text); color: var(--text); }
        .search-inp  { width: 100%; background: var(--bg); border: 1.5px solid var(--border); border-radius: var(--r-sm); padding: 10px 13px; color: var(--text); font-size: 14px; font-family: var(--font); outline: none; transition: border-color 0.15s; }
        .search-inp:focus { border-color: var(--accent); }

        /* Mobile nav */
        .mobile-nav  { display: none; position: fixed; bottom: 0; left: 0; right: 0; background: var(--white); border-top: 1px solid var(--border); padding: 6px 0 env(safe-area-inset-bottom, 6px); z-index: 40; box-shadow: 0 -4px 20px rgba(0,0,0,0.06); }
        .mob-btn     { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 6px 4px; background: transparent; border: none; color: var(--muted); font-size: 10px; font-weight: 600; cursor: pointer; font-family: var(--font); transition: all 0.15s; }
        .mob-btn.active { color: var(--accent); }
        .mob-icon    { font-size: 20px; }

        /* Overview grid */
        .overview-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }

        /* Responsive */
        @media (max-width: 1024px) {
          .stats-grid { grid-template-columns: repeat(2, 1fr); }
          .hero-stats { grid-template-columns: repeat(2, 1fr); }
          .overview-grid { grid-template-columns: 1fr; }
          .vitals-summary-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 768px) {
          .sidebar { display: none; }
          .content { padding: 16px; }
          .top-bar { padding: 12px 16px; }
          .tb-name { font-size: 16px; }
          .stats-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
          .chat-shell { grid-template-columns: 1fr; }
          .chat-sidebar { display: none; }
          .mobile-nav { display: flex; }
          .form-grid-2 { grid-template-columns: 1fr; }
          .hero-stats { grid-template-columns: repeat(2, 1fr); }
          .as-concern { display: none; }
        }
      `}</style>

      <div className="shell">
        {/* Sidebar */}
        <aside className="sidebar">
          <div className="sb-brand">
            <div className="sb-logo">
              <div className="sb-icon">⚕️</div>
              <div>
                <div className="sb-name">AMEXAN</div>
                <div className="sb-sub">Doctor Portal</div>
              </div>
            </div>
          </div>
          <div className="sb-profile">
            <div className="sb-ava">{doctor.name[0]}</div>
            <div className="sb-pname">Dr. {doctor.name}</div>
            <div className="sb-psub">{doctor.specialty || 'Specialist'}</div>
            <div className="sb-pemail">{doctor.email}</div>
          </div>
          <nav className="sb-nav">
            {tabs.map(t => (
              <button key={t.id} className={`sb-item ${activeTab === t.id ? 'active' : ''}`} onClick={() => setActiveTab(t.id as any)}>
                <span className="sb-item-icon">{t.icon}</span>
                {t.label}
                {t.badge !== undefined && t.badge > 0 && <span className="sb-badge">{t.badge}</span>}
              </button>
            ))}
          </nav>
          <div className="sb-footer">
            <button className="sb-signout" onClick={() => { signOut(auth); router.replace('/login'); }}>
              <span>🚪</span> Sign Out
            </button>
          </div>
        </aside>

        {/* Main */}
        <div className="main">
          {/* Top bar */}
          <div className="top-bar">
            <div className="tb-left">
              <span className="tb-greet">{getGreeting()},</span>
              <span className="tb-name">Dr. {doctor.name.split(' ')[0]} 👋</span>
            </div>
            <div className="tb-right">
              {activeAppts.length > 0 && (
                <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 700, color: 'var(--green)', background: 'var(--green-dim)', padding: '6px 12px', borderRadius: 99 }}>
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--green)', display: 'inline-block', animation: 'pulse-g 1.5s infinite' }} />
                  {activeAppts.length} Active Session{activeAppts.length > 1 ? 's' : ''}
                </span>
              )}
              <button className="tb-btn tb-btn-green" onClick={() => setActiveTab('queue')}>
                📋 View Queue ({upcomingAppts.length})
              </button>
              <button className="tb-btn" onClick={() => setActiveTab('services')}>
                + Add Service
              </button>
            </div>
          </div>

          <div className="content">
            {/* Overview */}
            {activeTab === 'overview' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div className="hero-card">
                  <div className="hero-greet">{getGreeting()}</div>
                  <div className="hero-name">Dr. {doctor.name}</div>
                  <div className="hero-chips">
                    {doctor.specialty && <span className="hero-chip">🩺 {doctor.specialty}</span>}
                    {doctor.clinic    && <span className="hero-chip">🏥 {doctor.clinic}</span>}
                    {doctor.location  && <span className="hero-chip">📍 {doctor.location}</span>}
                    {doctor.yearsExperience && <span className="hero-chip">⭐ {doctor.yearsExperience}y exp</span>}
                  </div>
                  <div className="hero-stats">
                    <div className="hero-stat">
                      <div className="hero-stat-val">{todayAppts.length}</div>
                      <div className="hero-stat-label">Today</div>
                    </div>
                    <div className="hero-stat">
                      <div className="hero-stat-val" style={{ color: '#34d399' }}>{activeAppts.length}</div>
                      <div className="hero-stat-label">Active</div>
                    </div>
                    <div className="hero-stat">
                      <div className="hero-stat-val">{patientIds.length}</div>
                      <div className="hero-stat-label">Patients</div>
                    </div>
                    <div className="hero-stat">
                      <div className="hero-stat-val">{services.filter(s => s.isAvailable).length}</div>
                      <div className="hero-stat-label">Services</div>
                    </div>
                  </div>
                </div>

                <div className="stats-grid">
                  <div className="stat-card"><span className="stat-icon">📅</span><div><div className="stat-val">{appointments.length}</div><div className="stat-lbl">Total Appointments</div></div></div>
                  <div className="stat-card"><span className="stat-icon">⏳</span><div><div className="stat-val" style={{ color: 'var(--indigo)' }}>{upcomingAppts.length}</div><div className="stat-lbl">In Queue</div></div></div>
                  <div className="stat-card"><span className="stat-icon">✅</span><div><div className="stat-val" style={{ color: 'var(--green)' }}>{completedAppts.length}</div><div className="stat-lbl">Completed</div></div></div>
                  <div className="stat-card"><span className="stat-icon">💰</span><div><div className="stat-val" style={{ color: 'var(--amber)', fontSize: 16 }}>KES {totalEarned.toLocaleString()}</div><div className="stat-lbl">Total Earned</div></div></div>
                </div>

                {activeAppts.length > 0 && (
                  <ActiveConsultationsPanel doctorId={doctor.uid} appointments={activeAppts} onStarted={() => {}} />
                )}

                <div className="overview-grid">
                  <div className="panel">
                    <div className="panel-hd">
                      <div className="panel-title">⏳ Today's Queue</div>
                      <button className="btn-sm-accent" onClick={() => setActiveTab('queue')}>Manage →</button>
                    </div>
                    {todayAppts.filter(a => a.status === 'booked').length === 0 ? (
                      <div className="empty-sm"><div style={{ fontSize: 28, marginBottom: 6 }}>📭</div><p>No bookings for today yet</p></div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {todayAppts.filter(a => a.status === 'booked').slice(0, 4).map(a => (
                          <div key={a.id} className="appt-card">
                            <div className="appt-left">
                              <div className="appt-icon-box">📅</div>
                              <div>
                                <div className="appt-spec">{a.patientName || 'Patient'}</div>
                                <div className="appt-dr">{a.specialty}</div>
                                <div className="appt-date">{fmtDate(a.date)}</div>
                              </div>
                            </div>
                            <span className="status-pill" style={{ background: statusConfig.booked.bg, color: statusConfig.booked.color }}>
                              {statusConfig.booked.label}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="panel">
                    <div className="panel-hd">
                      <div className="panel-title">🏥 Active Services</div>
                      <button className="btn-sm-accent" onClick={() => setActiveTab('services')}>Manage →</button>
                    </div>
                    {services.filter(s => s.isAvailable).length === 0 ? (
                      <div className="empty-sm"><div style={{ fontSize: 28, marginBottom: 6 }}>🏥</div><p>No live services. Add one so patients can find you.</p></div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {services.filter(s => s.isAvailable).slice(0, 4).map(s => (
                          <div key={s.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 12px', background: 'var(--bg)', borderRadius: 10, border: '1px solid var(--border)' }}>
                            <div>
                              <div style={{ fontWeight: 700, fontSize: 13 }}>{s.specialty}</div>
                              <div style={{ fontSize: 11, color: 'var(--muted)' }}>{s.clinic} · {s.duration}min</div>
                            </div>
                            <span style={{ fontWeight: 800, fontSize: 14, color: 'var(--accent)', fontFamily: 'var(--mono)' }}>
                              KES {s.price.toLocaleString()}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* Queue Tab */}
            {activeTab === 'queue' && (
              <ActiveConsultationsPanel
                doctorId={doctor.uid}
                appointments={[...activeAppts, ...upcomingAppts]}
                onStarted={() => {}}
              />
            )}

            {/* Patients Tab */}
            {activeTab === 'patients' && (
              <PatientsPanel doctorId={doctor.uid} appointments={appointments} />
            )}

            {/* History Tab */}
            {activeTab === 'history' && (
              <HistoryPanel appointments={appointments} />
            )}

            {/* Messages Tab */}
            {activeTab === 'messages' && (
              <ChatPanel doctorId={doctor.uid} patients={
                [...new Set(appointments.map(a => a.patientId))].map(id => {
                  const a = appointments.find(x => x.patientId === id);
                  return { uid: id, name: a?.patientName || 'Patient', email: a?.patientEmail || '', } as PatientRecord;
                })
              } />
            )}

            {/* Tools Tab */}
            {activeTab === 'tools' && (
              <DiseaseToolsPanel patients={
                [...new Set(appointments.map(a => a.patientId))].map(id => {
                  const a = appointments.find(x => x.patientId === id);
                  return { uid: id, name: a?.patientName || 'Patient', email: a?.patientEmail || '', condition: a?.specialty } as PatientRecord;
                })
              } />
            )}

            {/* Services Tab */}
            {activeTab === 'services' && (
              <ServicesPanel doctor={doctor} services={services} />
            )}

            {/* Earnings Tab */}
            {activeTab === 'earnings' && (
              <EarningsPanel appointments={appointments} />
            )}

            {/* Settings Tab */}
            {activeTab === 'settings' && (
              <SettingsPanel
                doctor={doctor}
                onUpdated={async () => {
                  const snap = await getDoc(doc(db, 'users', doctor.uid));
                  const data = snap.data() || {};
                  setDoctor(prev => prev ? { ...prev, ...data } : prev);
                }}
              />
            )}
          </div>
        </div>
      </div>

      {/* Mobile Bottom Nav */}
      <nav className="mobile-nav">
        {[
          { id: 'overview',  icon: '🏠', label: 'Home' },
          { id: 'queue',     icon: '📋', label: 'Queue' },
          { id: 'patients',  icon: '👥', label: 'Patients' },
          { id: 'messages',  icon: '💬', label: 'Messages' },
          { id: 'services',  icon: '🏥', label: 'Services' },
        ].map(t => (
          <button key={t.id} className={`mob-btn ${activeTab === t.id ? 'active' : ''}`} onClick={() => setActiveTab(t.id as any)}>
            <span className="mob-icon">{t.icon}</span>
            {t.label}
          </button>
        ))}
      </nav>
    </>
  );
}