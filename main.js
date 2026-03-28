const { app, BrowserWindow, Menu, ipcMain, dialog, clipboard, shell, nativeTheme } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

let mainWindow;
const activeDownloads = new Map();

const CONFIG_PATH = path.join(app.getPath('userData'), 'config.json');
const HISTORY_PATH = path.join(app.getPath('userData'), 'history.json');

// ── Config ──────────────────────────────────────────
function loadConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
  } catch {
    return null;
  }
}

function saveConfig(config) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

function getConfig() {
  return loadConfig() || {
    downloadFolderVideo: '',
    downloadFolderAudio: '',
    concurrentDownloads: 3,
    bandwidthLimit: 0,
    preventSleep: true,
    videoQuality: 'highest',
    videoResolution: '1080',
    videoFormat: 'mp4',
    audioFormat: 'mp3',
    audioBitrate: '192',
    audioSamplerate: '44100',
    filenameTemplate: 'title',
    skipExisting: false,
    removeEmoji: false,
    sponsorBlock: false,
    embedSubtitles: false,
    subtitleLangs: 'en',
    embedThumbnail: false,
    saveThumbnail: false,
    writeTags: true,
    cookiesBrowser: 'none',
    proxy: '',
    autoClipboard: false,
    autoStart: false,
    autoRemoveCompleted: false,
    createPlaylistSubfolder: true,
    notifications: { added: false, started: true, completed: true },
    firstLaunch: true
  };
}

// ── History ─────────────────────────────────────────
function loadHistory() {
  try {
    return JSON.parse(fs.readFileSync(HISTORY_PATH, 'utf-8'));
  } catch {
    return [];
  }
}

function saveHistory(history) {
  fs.writeFileSync(HISTORY_PATH, JSON.stringify(history, null, 2));
}

function addToHistory(entry) {
  const history = loadHistory();
  history.unshift({
    ...entry,
    downloadedAt: new Date().toISOString()
  });
  // Keep last 500 entries
  if (history.length > 500) history.length = 500;
  saveHistory(history);
}

// ── yt-dlp helpers ──────────────────────────────────
function findYtDlp() {
  const locations = [
    '/opt/homebrew/bin/yt-dlp',
    '/usr/local/bin/yt-dlp',
    '/usr/bin/yt-dlp',
    'yt-dlp'
  ];
  for (const loc of locations) {
    try {
      require('child_process').execSync(`${loc} --version`, { stdio: 'ignore' });
      return loc;
    } catch {}
  }
  return 'yt-dlp';
}

const YT_DLP = findYtDlp();

function buildArgs(url, config, mode, formatId) {
  const args = ['--no-warnings', '--newline'];

  // Progress template for parsing
  args.push('--progress-template', 'download:%(progress._percent_str)s %(progress._speed_str)s %(progress._eta_str)s');

  // Output template
  let outputDir = mode === 'audio' ? config.downloadFolderAudio : config.downloadFolderVideo;
  // Resolve ~ to actual home directory
  if (outputDir && outputDir.startsWith('~')) {
    outputDir = outputDir.replace('~', app.getPath('home'));
  }
  if (!outputDir) outputDir = path.join(app.getPath('downloads'), 'SKD Downloader');
  // Ensure directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  let filenamePattern;
  if (config.filenameTemplate === 'title') {
    filenamePattern = '%(title)s.%(ext)s';
  } else if (config.filenameTemplate === 'artist-title') {
    filenamePattern = '%(artist)s - %(title)s.%(ext)s';
  } else {
    filenamePattern = '%(title)s.%(ext)s';
  }

  args.push('-o', path.join(outputDir, filenamePattern));

  if (config.createPlaylistSubfolder) {
    args.push('-o', `playlist:${path.join(outputDir, '%(playlist_title)s', filenamePattern)}`);
  }

  // Format selection
  if (mode === 'audio') {
    args.push('-x');
    args.push('--audio-format', config.audioFormat || 'mp3');
    args.push('--audio-quality', config.audioBitrate ? `${config.audioBitrate}K` : '192K');
  } else if (formatId) {
    args.push('-f', formatId);
  } else if (config.videoQuality === 'highest') {
    args.push('-f', `bestvideo[ext=${config.videoFormat || 'mp4'}]+bestaudio/best[ext=${config.videoFormat || 'mp4'}]/bestvideo+bestaudio/best`);
  } else if (config.videoQuality === 'lowest') {
    args.push('-f', 'worstvideo+worstaudio/worst');
  } else {
    const res = config.videoResolution || '1080';
    args.push('-f', `bestvideo[height<=${res}][ext=${config.videoFormat || 'mp4'}]+bestaudio/best[height<=${res}]/bestvideo[height<=${res}]+bestaudio/best`);
  }

  // Merge to mp4 for video
  if (mode === 'video') {
    args.push('--merge-output-format', config.videoFormat || 'mp4');
  }

  // SponsorBlock
  if (config.sponsorBlock) {
    args.push('--sponsorblock-remove', 'all');
  }

  // Subtitles
  if (config.embedSubtitles && mode === 'video') {
    args.push('--write-subs', '--embed-subs');
    if (config.subtitleLangs) args.push('--sub-langs', config.subtitleLangs);
  }

  // Thumbnail
  if (config.embedThumbnail) {
    args.push('--embed-thumbnail');
  }
  if (config.saveThumbnail) {
    args.push('--write-thumbnail');
  }

  // Tags
  if (config.writeTags && mode === 'audio') {
    args.push('--embed-metadata');
  }

  // Cookies
  if (config.cookiesBrowser && config.cookiesBrowser !== 'none') {
    args.push('--cookies-from-browser', config.cookiesBrowser);
  }

  // Bandwidth
  if (config.bandwidthLimit > 0) {
    args.push('-r', `${config.bandwidthLimit}K`);
  }

  // Proxy
  if (config.proxy) {
    args.push('--proxy', config.proxy);
  }

  // Skip existing
  if (config.skipExisting) {
    args.push('--no-overwrites');
  }

  // Remove emoji
  if (config.removeEmoji) {
    args.push('--replace-in-metadata', 'title', '[\\U00010000-\\U0010ffff]', '');
  }

  args.push(url);
  return args;
}

// ── Window ──────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 960,
    height: 700,
    minWidth: 800,
    minHeight: 600,
    backgroundColor: '#0a0a0f',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    },
    show: false
  });

  mainWindow.loadFile('src/index.html');
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    // Check first launch
    const config = getConfig();
    if (config.firstLaunch) {
      mainWindow.webContents.send('first-launch');
    }
  });
}

app.whenReady().then(() => {
  // Enable Cmd+C/V/X/A on macOS (Electron swallows them without a menu)
  if (process.platform === 'darwin') {
    Menu.setApplicationMenu(Menu.buildFromTemplate([
      {
        label: app.name,
        submenu: [
          { role: 'about' },
          { type: 'separator' },
          { role: 'quit' }
        ]
      },
      {
        label: 'Edit',
        submenu: [
          { role: 'undo' },
          { role: 'redo' },
          { type: 'separator' },
          { role: 'cut' },
          { role: 'copy' },
          { role: 'paste' },
          { role: 'selectAll' }
        ]
      }
    ]));
  }
  createWindow();
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });

// ── IPC Handlers ────────────────────────────────────

ipcMain.handle('get-config', () => getConfig());

ipcMain.handle('save-config', (_, config) => {
  saveConfig(config);
  return true;
});

ipcMain.handle('select-folder', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory']
  });
  if (result.canceled) return null;
  return result.filePaths[0];
});

ipcMain.handle('paste-clipboard', () => clipboard.readText());

ipcMain.handle('get-video-info', async (_, url) => {
  return new Promise((resolve, reject) => {
    const args = ['--dump-json', '--no-warnings', '--flat-playlist', url];
    const config = getConfig();
    if (config.cookiesBrowser && config.cookiesBrowser !== 'none') {
      args.unshift('--cookies-from-browser', config.cookiesBrowser);
    }
    const proc = spawn(YT_DLP, args);
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', d => stdout += d.toString());
    proc.stderr.on('data', d => stderr += d.toString());

    proc.on('close', code => {
      if (code !== 0) return reject(new Error(stderr || `yt-dlp exited with code ${code}`));
      try {
        // Handle playlists (multiple JSON objects)
        const lines = stdout.trim().split('\n');
        const entries = lines.map(l => JSON.parse(l));
        resolve(entries.length === 1 ? entries[0] : entries);
      } catch (e) {
        reject(new Error('Failed to parse video info'));
      }
    });

    setTimeout(() => { proc.kill(); reject(new Error('Timeout')); }, 30000);
  });
});

ipcMain.handle('get-formats', async (_, url) => {
  return new Promise((resolve, reject) => {
    const proc = spawn(YT_DLP, ['-F', '--no-warnings', url]);
    let stdout = '';
    proc.stdout.on('data', d => stdout += d.toString());
    proc.on('close', code => {
      if (code !== 0) return reject(new Error('Failed to get formats'));
      resolve(stdout);
    });
    setTimeout(() => { proc.kill(); reject(new Error('Timeout')); }, 15000);
  });
});

ipcMain.handle('start-download', (_, { id, url, mode, formatId }) => {
  const config = getConfig();
  const args = buildArgs(url, config, mode, formatId);

  const proc = spawn(YT_DLP, args);
  activeDownloads.set(id, proc);

  let lastFilePath = '';

  proc.stdout.on('data', data => {
    const lines = data.toString().split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      // Parse progress
      const progressMatch = trimmed.match(/(\d+\.?\d*)%\s+(\S+)\s+(\S+)/);
      if (progressMatch) {
        mainWindow.webContents.send('download-progress', {
          id,
          percent: parseFloat(progressMatch[1]),
          speed: progressMatch[2],
          eta: progressMatch[3]
        });
      }

      // Parse destination filename (multiple patterns)
      const destMatch = trimmed.match(/\[download\] Destination: (.+)/) ||
                        trimmed.match(/\[Merger\] Merging formats into "(.+)"/) ||
                        trimmed.match(/\[ExtractAudio\] Destination: (.+)/) ||
                        trimmed.match(/\[ffmpeg\] Destination: (.+)/);
      if (destMatch) {
        lastFilePath = destMatch[1].replace(/^"(.*)"$/, '$1');
        mainWindow.webContents.send('download-destination', { id, path: lastFilePath });
      }

      // Also catch "has already been downloaded"
      const alreadyMatch = trimmed.match(/\[download\] (.+) has already been downloaded/);
      if (alreadyMatch) {
        lastFilePath = alreadyMatch[1];
        mainWindow.webContents.send('download-destination', { id, path: lastFilePath });
      }

      // Parse merge/extract
      if (trimmed.includes('[Merger]') || trimmed.includes('[ExtractAudio]')) {
        mainWindow.webContents.send('download-progress', { id, percent: 99, speed: '', eta: 'Processing...' });
      }
    }
  });

  proc.stderr.on('data', data => {
    const line = data.toString().trim();
    if (line.includes('ERROR')) {
      mainWindow.webContents.send('download-error', { id, error: line });
    }
  });

  proc.on('close', code => {
    activeDownloads.delete(id);
    if (code === 0) {
      mainWindow.webContents.send('download-complete', { id });
    } else {
      mainWindow.webContents.send('download-error', { id, error: `Process exited with code ${code}` });
    }
  });

  return true;
});

ipcMain.handle('cancel-download', (_, id) => {
  const proc = activeDownloads.get(id);
  if (proc) {
    proc.kill('SIGTERM');
    activeDownloads.delete(id);
  }
  return true;
});

ipcMain.handle('get-history', () => loadHistory());

ipcMain.handle('clear-history', () => {
  saveHistory([]);
  return true;
});

ipcMain.handle('add-to-history', (_, entry) => {
  addToHistory(entry);
  return true;
});

ipcMain.handle('open-file', (_, filePath) => {
  shell.showItemInFolder(filePath);
});

ipcMain.handle('open-url', (_, url) => {
  shell.openExternal(url);
});

ipcMain.handle('get-downloads-path', () => {
  return path.join(app.getPath('downloads'), 'SKD Downloader');
});

ipcMain.handle('check-ytdlp', () => {
  try {
    const version = require('child_process').execSync(`${YT_DLP} --version`).toString().trim();
    return { installed: true, version, path: YT_DLP };
  } catch {
    return { installed: false };
  }
});
