const refreshButton = document.querySelector('#refreshButton');
const lastUpdated = document.querySelector('#lastUpdated');
const summary = document.querySelector('#summary');
const servicesRoot = document.querySelector('#services');
const logTitle = document.querySelector('#logTitle');
const logMeta = document.querySelector('#logMeta');
const logOutput = document.querySelector('#logOutput');
const lineCount = document.querySelector('#lineCount');

const state = {
  services: [],
  selectedServiceId: null,
};

const groupOrder = ['infra', 'core', 'wallet'];
const groupTitles = {
  infra: 'Infrastructure',
  core: 'Core services',
  wallet: 'Wallet and MTPA',
};

const escapeHtml = (value) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;');

const serviceStateClass = (service) => {
  if (!service.running) {
    return 'error';
  }
  if (service.health?.state === 'error') {
    return 'warn';
  }
  return 'ok';
};

const healthLabel = (service) => {
  if (service.healthUrl == null) {
    return service.running ? 'No HTTP health' : 'Stopped';
  }

  if (service.health?.state === 'ok') {
    return `Health OK${service.health.detail ? `: ${service.health.detail}` : ''}`;
  }

  if (service.health?.state === 'error') {
    return `Health error${service.health.detail ? `: ${service.health.detail}` : ''}`;
  }

  return 'Health unknown';
};

const renderSummary = (totals) => {
  summary.innerHTML = `
    <article class="summary-card">
      <span class="summary-label">Total</span>
      <strong>${totals.total}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Running</span>
      <strong>${totals.running}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Stopped</span>
      <strong>${totals.stopped}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Health issues</span>
      <strong>${totals.unhealthy}</strong>
    </article>
  `;
};

const renderServices = () => {
  const grouped = new Map(groupOrder.map((group) => [group, []]));

  for (const service of state.services) {
    grouped.get(service.group)?.push(service);
  }

  servicesRoot.innerHTML = groupOrder.map((group) => {
    const services = grouped.get(group) ?? [];
    return `
      <section class="service-group">
        <header class="group-header">
          <h3>${groupTitles[group] ?? group}</h3>
        </header>
        <div class="service-grid">
          ${services.map((service) => {
            const tone = serviceStateClass(service);
            const selected = service.id === state.selectedServiceId ? ' selected' : '';
            return `
              <button class="service-card ${tone}${selected}" data-service-id="${service.id}">
                <div class="service-card-top">
                  <span class="service-name">${service.name}</span>
                  <span class="badge ${tone}">${service.running ? 'UP' : 'DOWN'}</span>
                </div>
                <div class="service-card-meta">
                  <span>${healthLabel(service)}</span>
                  <span>${service.port != null ? `Port ${service.port}` : 'No port'}</span>
                  <span>${service.pid != null ? `PID ${service.pid}` : 'No PID file'}</span>
                </div>
              </button>
            `;
          }).join('')}
        </div>
      </section>
    `;
  }).join('');

  for (const button of servicesRoot.querySelectorAll('[data-service-id]')) {
    button.addEventListener('click', () => {
      state.selectedServiceId = button.dataset.serviceId;
      renderServices();
      void refreshLogs();
    });
  }
};

const refreshStatus = async () => {
  const response = await fetch('/api/status', { cache: 'no-store' });
  if (!response.ok) {
    throw new Error(`Status request failed with ${response.status}`);
  }

  const payload = await response.json();
  state.services = payload.services;
  if (state.selectedServiceId == null || !state.services.some((service) => service.id === state.selectedServiceId)) {
    const preferred = state.services.find((service) => !service.running || service.health?.state === 'error') ?? state.services[0];
    state.selectedServiceId = preferred?.id ?? null;
  }

  renderSummary(payload.totals);
  renderServices();
  lastUpdated.textContent = `Updated ${new Date(payload.generatedAt).toLocaleTimeString()}`;
};

const refreshLogs = async () => {
  const selected = state.services.find((service) => service.id === state.selectedServiceId);

  if (selected == null) {
    logTitle.textContent = 'Logs';
    logMeta.textContent = 'Select a service card to view its log.';
    logOutput.textContent = 'No service selected.';
    return;
  }

  const response = await fetch(`/api/logs?id=${encodeURIComponent(selected.id)}&lines=${encodeURIComponent(lineCount.value)}`, {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`Log request failed with ${response.status}`);
  }

  const payload = await response.json();
  logTitle.textContent = selected.name;
  logMeta.textContent = payload.exists
    ? `${payload.path} · ${payload.updatedAt ?? 'unknown update'}${payload.truncated ? ' · showing tail only' : ''}`
    : 'No log file found for this service yet.';
  logOutput.innerHTML = payload.exists
    ? escapeHtml(payload.text || '(log file is empty)')
    : 'Log file not found.';
};

const refreshAll = async () => {
  try {
    await refreshStatus();
    await refreshLogs();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    lastUpdated.textContent = `Refresh failed: ${message}`;
  }
};

refreshButton.addEventListener('click', () => {
  void refreshAll();
});

lineCount.addEventListener('change', () => {
  void refreshLogs();
});

void refreshAll();
window.setInterval(() => {
  void refreshStatus();
}, 5000);
window.setInterval(() => {
  void refreshLogs();
}, 2500);
