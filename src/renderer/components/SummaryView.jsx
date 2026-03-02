import React from 'react';
import { motion } from 'framer-motion';

const TYPE_LABELS = {
  feature: 'Features',
  fix: 'Fixes',
  refactor: 'Refactor',
  docs: 'Docs',
  test: 'Tests',
  style: 'Style',
  deps: 'Deps',
  config: 'Config',
  init: 'Setup',
  remove: 'Removed',
  other: 'Other',
};

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.05 },
  },
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}

function formatTime(dateStr) {
  return new Date(dateStr).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });
}

export default function SummaryView({ summary, commits }) {
  const { overview, repoSummaries, dailyActivity, stats } = summary;

  const maxDayCommits = Math.max(...dailyActivity.map((d) => d.count), 1);

  return (
    <motion.div
      className="summary-container"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div className="summary-header" variants={item}>
        <h1>Your Dev Summary</h1>
        <div className="summary-date">
          Generated {new Date().toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          })}
        </div>
      </motion.div>

      {/* Overview */}
      <motion.div className="overview-card" variants={item}>
        <p className="overview-text">{overview}</p>
      </motion.div>

      {/* Stats */}
      <motion.div className="stats-row" variants={item}>
        <div className="stat-card">
          <div className="stat-number">{stats.totalCommits}</div>
          <div className="stat-label">Commits</div>
        </div>
        <div className="stat-card">
          <div className="stat-number">{stats.activeRepos}</div>
          <div className="stat-label">Active Repos</div>
        </div>
        <div className="stat-card">
          <div className="stat-number">{stats.activeDays}</div>
          <div className="stat-label">Active Days</div>
        </div>
      </motion.div>

      {/* Daily Activity */}
      {dailyActivity.length > 0 && (
        <motion.div className="section" variants={item}>
          <div className="section-title">Daily Activity</div>
          <div className="activity-grid">
            {dailyActivity.slice(0, 14).reverse().map((day) => (
              <div key={day.date} className="activity-day">
                <div
                  className="activity-bar"
                  style={{
                    height: `${Math.max(8, (day.count / maxDayCommits) * 80)}px`,
                    background: day.count > 0
                      ? `rgba(0, 113, 227, ${0.2 + (day.count / maxDayCommits) * 0.8})`
                      : 'var(--bg-tertiary)',
                  }}
                  title={`${day.count} commits on ${day.date}`}
                />
                <span className="activity-label">
                  {new Date(day.date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'narrow' })}
                </span>
              </div>
            ))}
          </div>
        </motion.div>
      )}

      {/* Per-Repo Summaries */}
      <motion.div className="section" variants={item}>
        <div className="section-title">By Project</div>
        {repoSummaries.map((repo) => (
          <motion.div key={repo.repo} className="repo-summary-card" variants={item}>
            <div className="repo-card-header">
              <span className="repo-card-name">{repo.repo}</span>
              <span className="repo-card-count">
                {repo.commitCount} commit{repo.commitCount !== 1 ? 's' : ''}
              </span>
            </div>
            <div className="repo-card-tags">
              {Object.entries(repo.types).map(([type, count]) => (
                <span key={type} className={`tag tag-${type}`}>
                  {TYPE_LABELS[type] || type} ({count})
                </span>
              ))}
            </div>
            <ul className="repo-summary-list">
              {repo.summary.map((line, i) => (
                <li key={i}>{line}</li>
              ))}
            </ul>
          </motion.div>
        ))}
      </motion.div>

      {/* Recent Commits */}
      <motion.div className="section" variants={item}>
        <div className="section-title">Recent Commits</div>
        <div className="commit-list">
          {commits.slice(0, 50).map((commit) => (
            <div key={commit.hash} className="commit-item">
              <div className="commit-dot" />
              <div className="commit-info">
                <div className="commit-subject">{commit.subject}</div>
                <div className="commit-meta">
                  <span>{formatDate(commit.date)}</span>
                  <span>{formatTime(commit.date)}</span>
                </div>
              </div>
              <span className="commit-repo-tag">{commit.repo}</span>
            </div>
          ))}
        </div>
      </motion.div>
    </motion.div>
  );
}
