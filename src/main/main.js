const { app, BrowserWindow, ipcMain, nativeTheme, shell } = require('electron');
const path = require('path');
const { scanForRepos, getCommits, getRepoStats } = require('./git-service');
const { generateSummary } = require('./summarizer');

const fs = require('fs');
const distPath = path.join(__dirname, '..', '..', 'dist', 'index.html');
const isDev = !app.isPackaged && !fs.existsSync(distPath);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#1a1a1a' : '#ffffff',
    vibrancy: 'sidebar',
    visualEffectState: 'active',
    webPreferences: {
      preload: path.join(__dirname, '..', 'preload', 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    show: false,
  });

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
  } else {
    mainWindow.loadFile(path.join(__dirname, '..', '..', 'dist', 'index.html'));
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// --- IPC Handlers ---

ipcMain.handle('scan-repos', async (_, scanPaths) => {
  try {
    const repos = await scanForRepos(scanPaths);
    return { success: true, data: repos };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('get-commits', async (_, { repoPaths, since, until }) => {
  try {
    const commits = await getCommits(repoPaths, since, until);
    return { success: true, data: commits };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('get-summary', async (_, { commits, period }) => {
  try {
    const summary = generateSummary(commits, period);
    return { success: true, data: summary };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('get-repo-stats', async (_, repoPath) => {
  try {
    const stats = await getRepoStats(repoPath);
    return { success: true, data: stats };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('get-theme', () => {
  return nativeTheme.shouldUseDarkColors ? 'dark' : 'light';
});

nativeTheme.on('updated', () => {
  const theme = nativeTheme.shouldUseDarkColors ? 'dark' : 'light';
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('theme-changed', theme);
  }
});

ipcMain.handle('get-default-scan-paths', () => {
  const home = app.getPath('home');
  return [
    path.join(home, 'Development'),
    path.join(home, 'Projects'),
    path.join(home, 'Code'),
    path.join(home, 'repos'),
    path.join(home, 'src'),
  ];
});
