/* ---------- BOOT ---------- */
renderRoles();
renderFacilities();
const q=new URLSearchParams(location.search);
const startView=q.get('view');
const startRole=q.get('role');
if(restoreSession() && !startRole){
  const savedView=q.get('view')||'dashboard';
  go(savedView);
} else if(startRole && ROLES.some(r=>r.id===startRole)){
  S.role=startRole; S.facility=q.get('facility')||'ktrh'; S.session={role:S.role,facility:S.facility};
  loadEnc(S.encounter);
  auditLog('Demo session auto-started — '+startRole);
  go(startView||'dashboard');
} else if(startView && !['landing','auth','facility'].includes(startView)){
  S.role='clinician'; S.facility='ktrh'; S.session={role:S.role,facility:S.facility};
  loadEnc(S.encounter);
  auditLog('Demo session auto-started');
  go(startView);
} else {
  if(S.encounter) loadEnc(S.encounter);
  go(startView||'landing');
}