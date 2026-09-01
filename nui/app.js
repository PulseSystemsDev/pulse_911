const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pulse_911';
let kind = 'emergency';
let labels = { emergency: '911 Call', non_emergency: '311 Call' };

const overlay = document.getElementById('overlay');
const dialog = document.getElementById('dialog');
const titleEl = document.getElementById('title');
const descEl = document.getElementById('desc');
const anonEl = document.getElementById('anon');
const anonWrap = document.getElementById('anonWrap');
const countEl = document.getElementById('count');
const stepKind = document.getElementById('stepKind');
const stepReason = document.getElementById('stepReason');
const pickEmergency = document.getElementById('pickEmergency');
const pickNonEmergency = document.getElementById('pickNonEmergency');
const errorEl = document.getElementById('error');

function post(name, body) {
  return fetch(`https://${RESOURCE}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {}),
  }).catch(() => {});
}

function updateCount() {
  countEl.textContent = `${descEl.value.length} / ${descEl.maxLength}`;
}

function truncateToMaxLength(value) {
  let result = '';
  for (const character of String(value || '')) {
    if (result.length + character.length > descEl.maxLength) break;
    result += character;
  }
  return result;
}

function setError(message) {
  errorEl.textContent = message;
  errorEl.classList.toggle('hidden', !message);
  descEl.setAttribute('aria-invalid', message ? 'true' : 'false');
}

function showKindStep(preselect) {
  setError('');
  stepKind.classList.remove('hidden');
  stepReason.classList.add('hidden');
  titleEl.textContent = 'Emergency Services';
  dialog.classList.remove('nonemerg');
  pickEmergency.classList.toggle('preselected', preselect === 'emergency');
  pickNonEmergency.classList.toggle('preselected', preselect === 'non_emergency');
}

function showReasonStep(chosen) {
  setError('');
  kind = chosen;
  stepKind.classList.add('hidden');
  stepReason.classList.remove('hidden');
  titleEl.textContent = labels[chosen] || (chosen === 'non_emergency' ? '311 Call' : '911 Call');
  dialog.classList.toggle('nonemerg', chosen === 'non_emergency');
  updateCount();
  setTimeout(() => descEl.focus(), 40);
}

function open(data) {
  if (data.labelEmergency) labels.emergency = data.labelEmergency;
  if (data.labelNonEmergency) labels.non_emergency = data.labelNonEmergency;
  const maxLength = Math.min(4000, Math.max(1, Math.trunc(Number(data.maxLength) || 300)));
  descEl.maxLength = maxLength;
  descEl.value = truncateToMaxLength(data.prefill);
  anonEl.checked = false;
  anonWrap.style.display = data.allowAnonymous ? 'flex' : 'none';
  overlay.classList.remove('hidden');
  showReasonStep(data.kind === 'non_emergency' ? 'non_emergency' : 'emergency');
}

function close() {
  if (overlay.classList.contains('hidden')) return;
  setError('');
  overlay.classList.add('hidden');
  post('close');
}

function send() {
  descEl.value = truncateToMaxLength(descEl.value);
  const description = descEl.value.trim();
  if (!description) {
    setError('Describe the situation before placing the call.');
    descEl.focus();
    return;
  }
  setError('');
  overlay.classList.add('hidden');
  post('submit', { kind, description, anonymous: anonEl.checked });
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'open') open(d);
});

pickEmergency.addEventListener('click', () => showReasonStep('emergency'));
pickNonEmergency.addEventListener('click', () => showReasonStep('non_emergency'));
document.getElementById('back').addEventListener('click', () => showKindStep(kind));
descEl.addEventListener('input', () => {
  descEl.value = truncateToMaxLength(descEl.value);
  setError('');
  updateCount();
});
document.getElementById('send').addEventListener('click', send);
document.getElementById('x').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
  if (overlay.classList.contains('hidden')) return;
  if (e.key === 'Escape') { e.preventDefault(); close(); }
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && !stepReason.classList.contains('hidden')) {
    e.preventDefault();
    send();
  }
});
