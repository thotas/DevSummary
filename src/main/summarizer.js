/**
 * Generates plain-English summaries from git commits.
 * Groups by repo, categorizes by type, and produces readable narratives.
 */

const COMMIT_PATTERNS = [
  { type: 'feature', patterns: [/^feat/i, /^add/i, /^implement/i, /^create/i, /^new/i, /^introduce/i], label: 'New Features', verb: 'Added' },
  { type: 'fix', patterns: [/^fix/i, /^bug/i, /^patch/i, /^resolve/i, /^hotfix/i, /^repair/i], label: 'Bug Fixes', verb: 'Fixed' },
  { type: 'refactor', patterns: [/^refactor/i, /^restructure/i, /^reorganize/i, /^simplif/i, /^clean/i, /^improve/i, /^enhance/i, /^optimiz/i, /^perf/i], label: 'Improvements', verb: 'Improved' },
  { type: 'docs', patterns: [/^doc/i, /^readme/i, /^comment/i, /^typo/i, /^spell/i], label: 'Documentation', verb: 'Updated docs for' },
  { type: 'test', patterns: [/^test/i, /^spec/i, /^coverage/i], label: 'Testing', verb: 'Added tests for' },
  { type: 'style', patterns: [/^style/i, /^format/i, /^lint/i, /^css/i, /^ui/i, /^design/i, /^layout/i], label: 'Styling', verb: 'Styled' },
  { type: 'deps', patterns: [/^dep/i, /^bump/i, /^upgrad/i, /^updat/i, /^install/i, /^packag/i], label: 'Dependencies', verb: 'Updated' },
  { type: 'config', patterns: [/^config/i, /^setup/i, /^env/i, /^build/i, /^ci/i, /^cd/i, /^deploy/i, /^docker/i], label: 'Configuration', verb: 'Configured' },
  { type: 'remove', patterns: [/^remov/i, /^delet/i, /^drop/i, /^deprecat/i], label: 'Removals', verb: 'Removed' },
  { type: 'init', patterns: [/^init/i, /^initial/i, /^first/i, /^bootstrap/i, /^scaffold/i, /🚀/], label: 'Project Setup', verb: 'Set up' },
];

function categorizeCommit(subject) {
  const cleaned = subject.replace(/^[\w-]+(\(.*?\))?[!:]?\s*/, '');

  for (const { type, patterns } of COMMIT_PATTERNS) {
    for (const pattern of patterns) {
      if (pattern.test(subject) || pattern.test(cleaned)) {
        return type;
      }
    }
  }
  return 'other';
}

function cleanSubject(subject) {
  // Remove conventional commit prefixes
  return subject
    .replace(/^[\w-]+(\(.*?\))?[!:]?\s*/, '')
    .replace(/^[🎉🚀🐛🔧📝✨💄🔥♻️✅🏗️⬆️🔒💚🔊🙈]\s*/, '')
    .replace(/^\w+:\s*/, '');
}

function groupByRepo(commits) {
  const groups = {};
  for (const commit of commits) {
    if (!groups[commit.repo]) {
      groups[commit.repo] = [];
    }
    groups[commit.repo].push(commit);
  }
  return groups;
}

function groupByDay(commits) {
  const groups = {};
  for (const commit of commits) {
    const day = commit.date.split('T')[0];
    if (!groups[day]) {
      groups[day] = [];
    }
    groups[day].push(commit);
  }
  return groups;
}

function generateRepoSummary(repoName, commits) {
  const categorized = {};
  for (const commit of commits) {
    const type = categorizeCommit(commit.subject);
    if (!categorized[type]) {
      categorized[type] = [];
    }
    categorized[type].push(commit);
  }

  const lines = [];

  for (const { type, label, verb } of COMMIT_PATTERNS) {
    const items = categorized[type];
    if (!items || items.length === 0) continue;

    if (items.length === 1) {
      lines.push(`${verb} ${cleanSubject(items[0].subject).toLowerCase()}`);
    } else if (items.length <= 3) {
      const subjects = items.map((c) => cleanSubject(c.subject).toLowerCase());
      lines.push(`${verb} ${subjects.slice(0, -1).join(', ')} and ${subjects[subjects.length - 1]}`);
    } else {
      const subjects = items.slice(0, 2).map((c) => cleanSubject(c.subject).toLowerCase());
      lines.push(`${verb} ${subjects.join(', ')}, and ${items.length - 2} more ${label.toLowerCase()} changes`);
    }
  }

  // Handle "other" category
  const otherItems = categorized['other'];
  if (otherItems && otherItems.length > 0) {
    if (otherItems.length <= 2) {
      for (const item of otherItems) {
        lines.push(`Made changes: ${cleanSubject(item.subject).toLowerCase()}`);
      }
    } else {
      lines.push(`Made ${otherItems.length} other changes`);
    }
  }

  return lines;
}

function formatPeriodLabel(period) {
  const labels = {
    '1w': 'this past week',
    '2w': 'the past two weeks',
    '1m': 'this past month',
    '3m': 'the past three months',
    '6m': 'the past six months',
    '1y': 'this past year',
  };
  return labels[period] || 'the selected period';
}

function generateSummary(commits, period) {
  if (commits.length === 0) {
    return {
      overview: `No commits found for ${formatPeriodLabel(period)}.`,
      repoSummaries: [],
      dailyActivity: [],
      stats: { totalCommits: 0, activeRepos: 0, activeDays: 0 },
    };
  }

  const byRepo = groupByRepo(commits);
  const byDay = groupByDay(commits);
  const repoNames = Object.keys(byRepo);
  const dayCount = Object.keys(byDay).length;

  // Generate per-repo summaries
  const repoSummaries = repoNames.map((repo) => {
    const repoCommits = byRepo[repo];
    const lines = generateRepoSummary(repo, repoCommits);
    const types = {};
    for (const c of repoCommits) {
      const t = categorizeCommit(c.subject);
      types[t] = (types[t] || 0) + 1;
    }
    return {
      repo,
      commitCount: repoCommits.length,
      summary: lines,
      types,
      latestCommit: repoCommits[0].date,
    };
  }).sort((a, b) => b.commitCount - a.commitCount);

  // Generate daily activity
  const dailyActivity = Object.entries(byDay)
    .map(([date, dayCommits]) => ({
      date,
      count: dayCommits.length,
      repos: [...new Set(dayCommits.map((c) => c.repo))],
    }))
    .sort((a, b) => b.date.localeCompare(a.date));

  // Generate overview paragraph
  const overview = generateOverview(commits, repoSummaries, period, dayCount);

  return {
    overview,
    repoSummaries,
    dailyActivity,
    stats: {
      totalCommits: commits.length,
      activeRepos: repoNames.length,
      activeDays: dayCount,
    },
  };
}

function generateOverview(commits, repoSummaries, period, dayCount) {
  const total = commits.length;
  const repoCount = repoSummaries.length;
  const periodLabel = formatPeriodLabel(period);

  let overview = `Over ${periodLabel}, you made ${total} commit${total !== 1 ? 's' : ''} across ${repoCount} project${repoCount !== 1 ? 's' : ''}, active on ${dayCount} day${dayCount !== 1 ? 's' : ''}.`;

  // Most active repo
  const topRepo = repoSummaries[0];
  if (topRepo && repoCount > 1) {
    overview += ` Your most active project was ${topRepo.repo} with ${topRepo.commitCount} commits.`;
  }

  // What kind of work
  const allTypes = {};
  for (const commit of commits) {
    const type = categorizeCommit(commit.subject);
    allTypes[type] = (allTypes[type] || 0) + 1;
  }

  const sorted = Object.entries(allTypes).sort((a, b) => b[1] - a[1]);
  if (sorted.length > 0) {
    const topType = sorted[0][0];
    const typeLabels = {
      feature: 'building new features',
      fix: 'fixing bugs',
      refactor: 'improving and refactoring code',
      docs: 'writing documentation',
      test: 'adding tests',
      style: 'working on UI and styling',
      deps: 'updating dependencies',
      config: 'configuring builds and tooling',
      remove: 'cleaning up code',
      init: 'setting up new projects',
      other: 'various development tasks',
    };
    overview += ` Most of your time was spent ${typeLabels[topType] || 'coding'}.`;
  }

  return overview;
}

module.exports = { generateSummary, categorizeCommit, cleanSubject };
