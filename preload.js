const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  selectFolder: () => ipcRenderer.invoke('select-folder'),
  pasteClipboard: () => ipcRenderer.invoke('paste-clipboard'),
  getVideoInfo: (url) => ipcRenderer.invoke('get-video-info', url),
  getFormats: (url) => ipcRenderer.invoke('get-formats', url),
  startDownload: (opts) => ipcRenderer.invoke('start-download', opts),
  cancelDownload: (id) => ipcRenderer.invoke('cancel-download', id),
  getHistory: () => ipcRenderer.invoke('get-history'),
  clearHistory: () => ipcRenderer.invoke('clear-history'),
  addToHistory: (entry) => ipcRenderer.invoke('add-to-history', entry),
  openFile: (path) => ipcRenderer.invoke('open-file', path),
  openUrl: (url) => ipcRenderer.invoke('open-url', url),
  getDownloadsPath: () => ipcRenderer.invoke('get-downloads-path'),
  checkYtDlp: () => ipcRenderer.invoke('check-ytdlp'),

  // Events from main process
  onDownloadProgress: (cb) => ipcRenderer.on('download-progress', (_, data) => cb(data)),
  onDownloadComplete: (cb) => ipcRenderer.on('download-complete', (_, data) => cb(data)),
  onDownloadError: (cb) => ipcRenderer.on('download-error', (_, data) => cb(data)),
  onDownloadDestination: (cb) => ipcRenderer.on('download-destination', (_, data) => cb(data)),
  onFirstLaunch: (cb) => ipcRenderer.on('first-launch', () => cb())
});
