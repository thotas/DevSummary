const { execFile } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs/promises');

const execFileAsync = promisify(execFile);

const MAX_DEPTH = 4;
const GIT_LOG_FORMAT = '%H%n%an%n%ae%n%aI%n%s%n%b%n---END---';

async function scanForRepos(scanPaths) {
  const repos = [];
  const seen = new Set();

  for (const scanPath of scanPaths) {
    try {
      await fs.access(scanPath);
    } catch {
      continue;
    }
    await walkForGitRepos(scanPath, 0, repos, seen);
  }

  return repos.sort((a, b) => a.name.localeCompare(b.name));
}

async function walkForGitRepos(dir, depth, repos, seen) {
  if (depth > MAX_DEPTH) return;

  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.') && entry.name !== '.git') continue;
      if (entry.name === 'node_modules' || entry.name === 'vendor' || entry.name === '.build') continue;

      const fullPath = path.join(dir, entry.name);

      if (entry.name === '.git') {
        const repoPath = dir;
        if (!seen.has(repoPath)) {
          seen.add(repoPath);
          const name = path.basename(repoPath);
          repos.push({ name, path: repoPath });
        }
        return;
      }

      await walkForGitRepos(fullPath, depth + 1, repos, seen);
    }
  } catch {
    // Skip directories we can't read
  }
}

async function getCommits(repoPaths, since, until) {
  const allCommits = [];

  const promises = repoPaths.map(async (repoPath) => {
    try {
      const args = [
        'log',
        '--all',
        `--since=${since}`,
        `--format=${GIT_LOG_FORMAT}`,
      ];

      if (until) {
        args.push(`--until=${until}`);
      }

      const { stdout } = await execFileAsync('git', args, {
        cwd: repoPath,
        timeout: 10000,
      });

      const repoName = path.basename(repoPath);
      const commits = parseGitLog(stdout, repoName, repoPath);
      return commits;
    } catch {
      return [];
    }
  });

  const results = await Promise.all(promises);
  for (const commits of results) {
    allCommits.push(...commits);
  }

  return allCommits.sort((a, b) => new Date(b.date) - new Date(a.date));
}

function parseGitLog(output, repoName, repoPath) {
  const commits = [];
  const entries = output.split('---END---\n').filter((e) => e.trim());

  for (const entry of entries) {
    const lines = entry.trim().split('\n');
    if (lines.length < 5) continue;

    const [hash, author, email, date, subject, ...bodyLines] = lines;
    const body = bodyLines.join('\n').trim();

    commits.push({
      hash: hash.trim(),
      author: author.trim(),
      email: email.trim(),
      date: date.trim(),
      subject: subject.trim(),
      body,
      repo: repoName,
      repoPath,
    });
  }

  return commits;
}

async function getRepoStats(repoPath) {
  try {
    const { stdout: branchOut } = await execFileAsync('git', ['branch', '--list'], {
      cwd: repoPath,
      timeout: 5000,
    });
    const branches = branchOut
      .split('\n')
      .filter((b) => b.trim())
      .map((b) => b.replace(/^\*?\s+/, ''));

    const { stdout: statusOut } = await execFileAsync('git', ['status', '--porcelain'], {
      cwd: repoPath,
      timeout: 5000,
    });
    const uncommittedChanges = statusOut.split('\n').filter((l) => l.trim()).length;

    const { stdout: remoteOut } = await execFileAsync('git', ['remote', '-v'], {
      cwd: repoPath,
      timeout: 5000,
    });
    const hasRemote = remoteOut.trim().length > 0;

    return {
      branches: branches.length,
      uncommittedChanges,
      hasRemote,
    };
  } catch {
    return { branches: 0, uncommittedChanges: 0, hasRemote: false };
  }
}

module.exports = { scanForRepos, getCommits, getRepoStats };
