// ── SKD Downloader — Renderer ───────────────────────

let config = {};
let queue = [];
let currentMode = 'video';
let downloadIdCounter = 0;

// ── Init ────────────────────────────────────────────
async function init() {
  config = await window.api.getConfig();

  // Check yt-dlp
  const ytdlp = await window.api.checkYtDlp();
  const versionEl = document.getElementById('ytdlpVersion');
  if (ytdlp.installed) {
    versionEl.textContent = `yt-dlp ${ytdlp.version}`;
  } else {
    versionEl.textContent = 'yt-dlp not found!';
    versionEl.style.color = '#ff4466';
  }

  // Show download folder in status bar
  updateStatusFolder();

  // Setup event listeners
  setupListeners();
  setupIpcListeners();
  setupSettings();

  // Update format selects based on mode
  updateFormatSelects();
}

function updateStatusFolder() {
  const folder = currentMode === 'audio' ? config.downloadFolderAudio : config.downloadFolderVideo;
  document.getElementById('statusFolder').textContent = folder || 'No folder set';
}

// ── Event Listeners ─────────────────────────────────
function setupListeners() {
  // Paste button
  document.getElementById('pasteBtn').addEventListener('click', async () => {
    const text = await window.api.pasteClipboard();
    if (text) document.getElementById('urlInput').value = text.trim();
  });

  // Add button
  document.getElementById('addBtn').addEventListener('click', () => addUrl());

  // Enter key on URL input
  document.getElementById('urlInput').addEventListener('keydown', e => {
    if (e.key === 'Enter') addUrl();
  });

  // Mode toggle
  const modeToggle = document.getElementById('modeToggle');
  modeToggle.querySelectorAll('.mode-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      currentMode = btn.dataset.mode;
      modeToggle.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      modeToggle.dataset.mode = currentMode;
      updateFormatSelects();
      updateStatusFolder();
    });
  });

  // Download all
  document.getElementById('downloadAllBtn').addEventListener('click', downloadAll);

  // Settings
  document.getElementById('settingsBtn').addEventListener('click', () => {
    loadSettingsUI();
    document.getElementById('settingsOverlay').style.display = 'flex';
  });
  document.getElementById('closeSettings').addEventListener('click', closeSettings);
  document.getElementById('settingsCancel').addEventListener('click', closeSettings);
  document.getElementById('settingsSave').addEventListener('click', saveSettings);

  // History
  document.getElementById('historyBtn').addEventListener('click', openHistory);
  document.getElementById('closeHistory').addEventListener('click', () => {
    document.getElementById('historyOverlay').style.display = 'none';
  });
  document.getElementById('clearHistory').addEventListener('click', async () => {
    await window.api.clearHistory();
    renderHistory([]);
  });
  document.getElementById('historySearch').addEventListener('input', filterHistory);

  // Settings tabs
  document.querySelectorAll('.settings-tabs .tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.settings-tabs .tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
    });
  });

  // Settings folder buttons
  document.getElementById('s-videoFolderBtn').addEventListener('click', async () => {
    const folder = await window.api.selectFolder();
    if (folder) document.getElementById('s-videoFolder').value = folder;
  });
  document.getElementById('s-audioFolderBtn').addEventListener('click', async () => {
    const folder = await window.api.selectFolder();
    if (folder) document.getElementById('s-audioFolder').value = folder;
  });

  // Concurrent slider
  document.getElementById('s-concurrent').addEventListener('input', e => {
    document.getElementById('s-concurrentVal').textContent = e.target.value;
  });

  // Embed subs toggle -> show lang input
  document.getElementById('s-embedSubs').addEventListener('change', e => {
    document.getElementById('subsLangGroup').style.display = e.target.checked ? 'block' : 'none';
  });

  // First launch
  window.api.onFirstLaunch(showFirstLaunch);

  // Status folder click -> open folder
  document.getElementById('statusFolder').addEventListener('click', () => {
    const folder = currentMode === 'audio' ? config.downloadFolderAudio : config.downloadFolderVideo;
    if (folder) window.api.openFile(folder);
  });

  // Close overlays on background click
  document.querySelectorAll('.overlay').forEach(overlay => {
    overlay.addEventListener('click', e => {
      if (e.target === overlay) {
        overlay.style.display = 'none';
      }
    });
  });
}

// ── IPC Listeners ───────────────────────────────────
function setupIpcListeners() {
  window.api.onDownloadProgress(data => {
    const item = queue.find(q => q.id === data.id);
    if (!item) return;
    item.status = 'downloading';
    item.percent = data.percent;
    item.speed = data.speed;
    item.eta = data.eta;
    renderQueueItem(item);
  });

  window.api.onDownloadComplete(data => {
    const item = queue.find(q => q.id === data.id);
    if (!item) return;
    item.status = 'completed';
    item.percent = 100;
    renderQueueItem(item);
    updateStatus();

    // Add to history
    window.api.addToHistory({
      title: item.title,
      url: item.url,
      thumbnail: item.thumbnail,
      duration: item.duration,
      mode: item.mode,
      filePath: item.filePath
    });

    // Start next queued download
    startNextInQueue();
  });

  window.api.onDownloadError(data => {
    const item = queue.find(q => q.id === data.id);
    if (!item) return;
    item.status = 'error';
    item.error = data.error;
    renderQueueItem(item);
    updateStatus();
    startNextInQueue();
  });

  window.api.onDownloadDestination(data => {
    const item = queue.find(q => q.id === data.id);
    if (item) item.filePath = data.path;
  });
}

// ── Format Selects ──────────────────────────────────
function updateFormatSelects() {
  const qualitySelect = document.getElementById('qualitySelect');
  const formatSelect = document.getElementById('formatSelect');
  const controlsRow = document.querySelector('.controls-row');

  if (currentMode === 'audio') {
    controlsRow.classList.add('audio-mode');
    // Replace format options with audio formats
    formatSelect.innerHTML = `
      <option value="mp3">MP3</option>
      <option value="m4a">M4A</option>
      <option value="flac">FLAC</option>
      <option value="wav">WAV</option>
      <option value="opus">Opus</option>
    `;
    // Replace quality with bitrate
    qualitySelect.innerHTML = `
      <option value="320">320 Kbps</option>
      <option value="256">256 Kbps</option>
      <option value="192" selected>192 Kbps</option>
      <option value="128">128 Kbps</option>
    `;
  } else {
    controlsRow.classList.remove('audio-mode');
    formatSelect.innerHTML = `
      <option value="mp4">MP4</option>
      <option value="mkv">MKV</option>
      <option value="webm">WebM</option>
    `;
    qualitySelect.innerHTML = `
      <option value="highest">Best Quality</option>
      <option value="2160">4K</option>
      <option value="1440">1440p</option>
      <option value="1080" selected>1080p</option>
      <option value="720">720p</option>
      <option value="480">480p</option>
    `;
  }
}

// ── Add URL ─────────────────────────────────────────
async function addUrl() {
  const input = document.getElementById('urlInput');
  const rawText = input.value.trim();
  if (!rawText) return;

  // Support multiple URLs (one per line)
  const urls = rawText.split('\n').map(u => u.trim()).filter(u => u && (u.startsWith('http') || u.startsWith('www')));
  if (urls.length === 0) {
    // Try as single URL
    if (rawText.startsWith('http') || rawText.startsWith('www')) {
      urls.push(rawText);
    } else {
      setStatus('Invalid URL');
      return;
    }
  }

  input.value = '';

  for (const url of urls) {
    const id = `dl_${++downloadIdCounter}`;
    const item = {
      id,
      url,
      title: 'Fetching info...',
      thumbnail: '',
      duration: '',
      status: 'fetching',
      percent: 0,
      speed: '',
      eta: '',
      mode: currentMode,
      filePath: '',
      error: ''
    };
    queue.push(item);
    renderQueue();
    updateDownloadButton();

    // Fetch video info
    try {
      const info = await window.api.getVideoInfo(url);

      if (Array.isArray(info)) {
        // Playlist — add each video
        queue = queue.filter(q => q.id !== id);
        for (const entry of info) {
          const subId = `dl_${++downloadIdCounter}`;
          queue.push({
            id: subId,
            url: entry.webpage_url || entry.url,
            title: entry.title || 'Unknown',
            thumbnail: entry.thumbnail || '',
            duration: formatDuration(entry.duration),
            status: 'queued',
            percent: 0,
            speed: '',
            eta: '',
            mode: currentMode,
            filePath: '',
            error: ''
          });
        }
        renderQueue();
        setStatus(`Added ${info.length} videos from playlist`);
      } else {
        item.title = info.title || 'Unknown';
        item.thumbnail = info.thumbnail || '';
        item.duration = formatDuration(info.duration);
        item.status = 'queued';
        renderQueueItem(item);
        setStatus(`Added: ${item.title}`);
      }
    } catch (e) {
      item.title = url;
      item.status = 'queued';
      renderQueueItem(item);
      setStatus('Could not fetch info, will download anyway');
    }

    updateDownloadButton();
  }
}

// ── Download ────────────────────────────────────────
function downloadAll() {
  const concurrent = config.concurrentDownloads || 3;
  const downloading = queue.filter(q => q.status === 'downloading').length;
  const toStart = concurrent - downloading;

  const queued = queue.filter(q => q.status === 'queued');
  for (let i = 0; i < Math.min(toStart, queued.length); i++) {
    startDownload(queued[i]);
  }
}

function startDownload(item) {
  item.status = 'downloading';
  item.percent = 0;
  renderQueueItem(item);
  updateStatus();

  // Get current toolbar selections
  const quality = document.getElementById('qualitySelect').value;
  const format = document.getElementById('formatSelect').value;

  // Temporarily update config for this download
  const downloadConfig = { ...config };
  if (item.mode === 'video') {
    if (quality === 'highest') {
      downloadConfig.videoQuality = 'highest';
    } else {
      downloadConfig.videoQuality = 'select';
      downloadConfig.videoResolution = quality;
    }
    downloadConfig.videoFormat = format;
  } else {
    downloadConfig.audioFormat = format;
    downloadConfig.audioBitrate = quality;
  }

  // Save temporarily so main process picks it up
  window.api.saveConfig(downloadConfig);

  window.api.startDownload({
    id: item.id,
    url: item.url,
    mode: item.mode
  });
}

function startNextInQueue() {
  const concurrent = config.concurrentDownloads || 3;
  const downloading = queue.filter(q => q.status === 'downloading').length;
  if (downloading >= concurrent) return;

  const next = queue.find(q => q.status === 'queued');
  if (next) startDownload(next);
}

function cancelDownload(id) {
  window.api.cancelDownload(id);
  queue = queue.filter(q => q.id !== id);
  renderQueue();
  updateDownloadButton();
}

function removeItem(id) {
  queue = queue.filter(q => q.id !== id);
  renderQueue();
  updateDownloadButton();
}

// ── Render Queue ────────────────────────────────────
function renderQueue() {
  const list = document.getElementById('queueList');
  const empty = document.getElementById('emptyState');

  if (queue.length === 0) {
    list.innerHTML = '';
    list.appendChild(empty);
    empty.style.display = 'flex';
    return;
  }

  empty.style.display = 'none';
  list.innerHTML = queue.map(item => buildQueueItemHtml(item)).join('');
  attachQueueListeners();
  updateStatus();
}

function renderQueueItem(item) {
  const existing = document.querySelector(`[data-id="${item.id}"]`);
  if (existing) {
    existing.outerHTML = buildQueueItemHtml(item);
    attachQueueListeners();
  }
  updateStatus();
}

function buildQueueItemHtml(item) {
  const thumbHtml = item.thumbnail
    ? `<img class="queue-thumb" src="${item.thumbnail}" alt="">`
    : `<div class="queue-thumb"></div>`;

  let statusHtml = '';
  let actionsHtml = '';

  switch (item.status) {
    case 'fetching':
      statusHtml = `<span class="status-badge fetching">Fetching...</span>`;
      actionsHtml = `<button class="btn-cancel" data-action="cancel" data-id="${item.id}">&times;</button>`;
      break;
    case 'queued':
      statusHtml = `<span class="status-badge queued">Queued</span>`;
      actionsHtml = `<button class="btn-cancel" data-action="remove" data-id="${item.id}">&times;</button>`;
      break;
    case 'downloading':
      statusHtml = `
        <div class="queue-progress">
          <div class="progress-bar-wrap">
            <div class="progress-bar" style="width: ${item.percent}%"></div>
          </div>
          <span class="progress-text">${Math.round(item.percent)}% ${item.speed || ''}</span>
        </div>`;
      actionsHtml = `<button class="btn-cancel" data-action="cancel" data-id="${item.id}">&#9724;</button>`;
      break;
    case 'completed':
      statusHtml = `<span class="status-badge completed">Done</span>`;
      actionsHtml = `
        ${item.filePath ? `<button data-action="open" data-id="${item.id}" title="Show in folder">&#128194;</button>` : ''}
        <button data-action="remove" data-id="${item.id}" title="Remove">&times;</button>`;
      break;
    case 'error':
      statusHtml = `<span class="status-badge error" title="${item.error || 'Error'}">Error</span>`;
      actionsHtml = `<button data-action="remove" data-id="${item.id}">&times;</button>`;
      break;
  }

  return `
    <div class="queue-item" data-id="${item.id}">
      ${thumbHtml}
      <div class="queue-info">
        <div class="queue-item-title">${escapeHtml(item.title)}</div>
        <div class="queue-item-meta">
          <span>${extractDomain(item.url)}</span>
          ${item.duration ? `<span class="dot"></span><span>${item.duration}</span>` : ''}
        </div>
      </div>
      ${statusHtml}
      <div class="queue-actions">${actionsHtml}</div>
    </div>`;
}

function attachQueueListeners() {
  document.querySelectorAll('.queue-actions button').forEach(btn => {
    btn.addEventListener('click', e => {
      const action = btn.dataset.action;
      const id = btn.dataset.id;
      if (action === 'cancel') cancelDownload(id);
      else if (action === 'remove') removeItem(id);
      else if (action === 'open') {
        const item = queue.find(q => q.id === id);
        if (item?.filePath) window.api.openFile(item.filePath);
      }
    });
  });
}

// ── Settings ────────────────────────────────────────
function setupSettings() {
  // First launch folder pickers
  document.getElementById('pickVideoFolder').addEventListener('click', async () => {
    const folder = await window.api.selectFolder();
    if (folder) {
      config.downloadFolderVideo = folder;
      document.getElementById('pickVideoFolder').textContent = folder;
      document.getElementById('pickVideoFolder').classList.add('selected');
    }
  });

  document.getElementById('pickAudioFolder').addEventListener('click', async () => {
    const folder = await window.api.selectFolder();
    if (folder) {
      config.downloadFolderAudio = folder;
      document.getElementById('pickAudioFolder').textContent = folder;
      document.getElementById('pickAudioFolder').classList.add('selected');
    }
  });

  document.getElementById('firstLaunchDone').addEventListener('click', async () => {
    if (!config.downloadFolderVideo) {
      // Default to ~/Downloads/SKD Downloader
      const downloads = '~/Downloads/SKD Downloader';
      config.downloadFolderVideo = downloads;
      config.downloadFolderAudio = downloads;
    }
    if (!config.downloadFolderAudio) {
      config.downloadFolderAudio = config.downloadFolderVideo;
    }
    config.firstLaunch = false;
    await window.api.saveConfig(config);
    document.getElementById('firstLaunchOverlay').style.display = 'none';
    updateStatusFolder();
  });
}

function showFirstLaunch() {
  document.getElementById('firstLaunchOverlay').style.display = 'flex';
}

function loadSettingsUI() {
  document.getElementById('s-autoClipboard').checked = config.autoClipboard || false;
  document.getElementById('s-autoStart').checked = config.autoStart || false;
  document.getElementById('s-autoRemoveCompleted').checked = config.autoRemoveCompleted || false;
  document.getElementById('s-notifStarted').checked = config.notifications?.started || false;
  document.getElementById('s-notifCompleted').checked = config.notifications?.completed || false;

  document.getElementById('s-concurrent').value = config.concurrentDownloads || 3;
  document.getElementById('s-concurrentVal').textContent = config.concurrentDownloads || 3;

  // Quality radio
  const qualityRadios = document.querySelectorAll('input[name="quality"]');
  qualityRadios.forEach(r => r.checked = r.value === (config.videoQuality || 'highest'));
  document.getElementById('s-resolution').value = config.videoResolution || '1080';

  document.getElementById('s-videoFolder').value = config.downloadFolderVideo || '';
  document.getElementById('s-audioFolder').value = config.downloadFolderAudio || '';
  document.getElementById('s-playlistSubfolder').checked = config.createPlaylistSubfolder !== false;
  document.getElementById('s-preventSleep').checked = config.preventSleep !== false;

  document.getElementById('s-bandwidth').value = config.bandwidthLimit || 0;
  document.getElementById('s-proxy').value = config.proxy || '';

  document.getElementById('s-filenameAudio').value = config.filenameTemplate || 'title';
  const audioFmtRadios = document.querySelectorAll('input[name="audioFmt"]');
  audioFmtRadios.forEach(r => r.checked = r.value === (config.audioFormat || 'mp3'));
  document.getElementById('s-bitrate').value = config.audioBitrate || '192';
  document.getElementById('s-samplerate').value = config.audioSamplerate || '44100';
  document.getElementById('s-skipExistingAudio').checked = config.skipExisting || false;
  document.getElementById('s-removeEmojiAudio').checked = config.removeEmoji || false;
  document.getElementById('s-sponsorBlockAudio').checked = config.sponsorBlock || false;

  document.getElementById('s-filenameVideo').value = config.filenameTemplate || 'title';
  const videoFmtRadios = document.querySelectorAll('input[name="videoFmt"]');
  videoFmtRadios.forEach(r => r.checked = r.value === (config.videoFormat || 'mp4'));
  document.getElementById('s-skipExistingVideo').checked = config.skipExisting || false;
  document.getElementById('s-removeEmojiVideo').checked = config.removeEmoji || false;
  document.getElementById('s-embedSubs').checked = config.embedSubtitles || false;
  document.getElementById('s-subLangs').value = config.subtitleLangs || 'en';
  document.getElementById('subsLangGroup').style.display = config.embedSubtitles ? 'block' : 'none';
  document.getElementById('s-sponsorBlockVideo').checked = config.sponsorBlock || false;

  const thumbRadios = document.querySelectorAll('input[name="thumb"]');
  if (config.embedThumbnail) thumbRadios[1].checked = true;
  else if (config.saveThumbnail) thumbRadios[2].checked = true;
  else thumbRadios[0].checked = true;

  document.getElementById('s-writeTags').checked = config.writeTags !== false;
  document.getElementById('s-embedThumb').checked = config.embedThumbnail || false;

  document.getElementById('s-cookies').value = config.cookiesBrowser || 'none';
}

async function saveSettings() {
  config.autoClipboard = document.getElementById('s-autoClipboard').checked;
  config.autoStart = document.getElementById('s-autoStart').checked;
  config.autoRemoveCompleted = document.getElementById('s-autoRemoveCompleted').checked;
  config.notifications = {
    started: document.getElementById('s-notifStarted').checked,
    completed: document.getElementById('s-notifCompleted').checked
  };

  config.concurrentDownloads = parseInt(document.getElementById('s-concurrent').value);

  const qualityRadio = document.querySelector('input[name="quality"]:checked');
  config.videoQuality = qualityRadio.value;
  config.videoResolution = document.getElementById('s-resolution').value;

  config.downloadFolderVideo = document.getElementById('s-videoFolder').value;
  config.downloadFolderAudio = document.getElementById('s-audioFolder').value;
  config.createPlaylistSubfolder = document.getElementById('s-playlistSubfolder').checked;
  config.preventSleep = document.getElementById('s-preventSleep').checked;

  config.bandwidthLimit = parseInt(document.getElementById('s-bandwidth').value) || 0;
  config.proxy = document.getElementById('s-proxy').value;

  config.filenameTemplate = document.getElementById('s-filenameAudio').value;
  config.audioFormat = document.querySelector('input[name="audioFmt"]:checked').value;
  config.audioBitrate = document.getElementById('s-bitrate').value;
  config.audioSamplerate = document.getElementById('s-samplerate').value;
  config.skipExisting = document.getElementById('s-skipExistingVideo').checked;
  config.removeEmoji = document.getElementById('s-removeEmojiVideo').checked;
  config.sponsorBlock = document.getElementById('s-sponsorBlockVideo').checked;

  config.videoFormat = document.querySelector('input[name="videoFmt"]:checked').value;
  config.embedSubtitles = document.getElementById('s-embedSubs').checked;
  config.subtitleLangs = document.getElementById('s-subLangs').value;

  const thumbRadio = document.querySelector('input[name="thumb"]:checked');
  config.embedThumbnail = thumbRadio.value === 'embed';
  config.saveThumbnail = thumbRadio.value === 'save';

  config.writeTags = document.getElementById('s-writeTags').checked;
  config.cookiesBrowser = document.getElementById('s-cookies').value;

  await window.api.saveConfig(config);
  closeSettings();
  updateStatusFolder();
  setStatus('Settings saved');
}

function closeSettings() {
  document.getElementById('settingsOverlay').style.display = 'none';
}

// ── History ─────────────────────────────────────────
let allHistory = [];

async function openHistory() {
  allHistory = await window.api.getHistory();
  renderHistory(allHistory);
  document.getElementById('historyOverlay').style.display = 'flex';
}

function renderHistory(items) {
  const list = document.getElementById('historyList');
  if (items.length === 0) {
    list.innerHTML = '<div class="history-empty">No downloads yet</div>';
    return;
  }

  list.innerHTML = items.map(item => `
    <div class="history-item">
      <div class="history-item-info">
        <div class="history-item-title">${escapeHtml(item.title)}</div>
        <div class="history-item-date">${new Date(item.downloadedAt).toLocaleString()}</div>
      </div>
      <span class="status-badge completed">${item.mode || 'video'}</span>
    </div>
  `).join('');
}

function filterHistory() {
  const query = document.getElementById('historySearch').value.toLowerCase();
  const filtered = allHistory.filter(h => h.title.toLowerCase().includes(query));
  renderHistory(filtered);
}

// ── Helpers ─────────────────────────────────────────
function formatDuration(seconds) {
  if (!seconds) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function extractDomain(url) {
  try {
    return new URL(url).hostname.replace('www.', '');
  } catch {
    return url;
  }
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function setStatus(text) {
  document.getElementById('statusText').textContent = text;
}

function updateStatus() {
  const downloading = queue.filter(q => q.status === 'downloading').length;
  const completed = queue.filter(q => q.status === 'completed').length;
  const total = queue.length;

  if (downloading > 0) {
    setStatus(`Downloading ${downloading} of ${total}`);
  } else if (completed === total && total > 0) {
    setStatus(`All ${total} downloads complete`);
  }

  document.getElementById('queueCount').textContent = `${total} item${total !== 1 ? 's' : ''}`;
}

function updateDownloadButton() {
  const queued = queue.filter(q => q.status === 'queued').length;
  const btn = document.getElementById('downloadAllBtn');
  btn.disabled = queued === 0;

  const span = btn.querySelector('span');
  if (queued > 0) {
    span.textContent = queued === 1 ? 'DOWNLOAD' : `DOWNLOAD ALL (${queued})`;
  } else {
    span.textContent = 'DOWNLOAD ALL';
  }
}

// ── Start ───────────────────────────────────────────
init();
