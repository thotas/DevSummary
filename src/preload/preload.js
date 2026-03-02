const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  scanRepos: (scanPaths) => ipcRenderer.invoke('scan-repos', scanPaths),
  getCommits: (params) => ipcRenderer.invoke('get-commits', params),
  getSummary: (params) => ipcRenderer.invoke('get-summary', params),
  getRepoStats: (repoPath) => ipcRenderer.invoke('get-repo-stats', repoPath),
  getTheme: () => ipcRenderer.invoke('get-theme'),
  getDefaultScanPaths: () => ipcRenderer.invoke('get-default-scan-paths'),
  onThemeChanged: (callback) => {
    ipcRenderer.on('theme-changed', (_, theme) => callback(theme));
    return () => ipcRenderer.removeAllListeners('theme-changed');
  },
});
