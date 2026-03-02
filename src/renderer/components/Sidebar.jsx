import React from 'react';
import { motion } from 'framer-motion';

export default function Sidebar({
  repos,
  selectedRepos,
  toggleRepo,
  selectAll,
  deselectAll,
  period,
  setPeriod,
  periodOptions,
  scanning,
}) {
  const allSelected = repos.length > 0 && selectedRepos.length === repos.length;

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-title">Time Range</div>
        <select
          className="period-select"
          value={period}
          onChange={(e) => setPeriod(e.target.value)}
        >
          {periodOptions.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
      </div>

      <div className="repo-section">
        <div className="repo-header">
          <span className="repo-header-title">
            Repositories ({selectedRepos.length}/{repos.length})
          </span>
          <div className="repo-header-actions">
            {allSelected ? (
              <button onClick={deselectAll}>None</button>
            ) : (
              <button onClick={selectAll}>All</button>
            )}
          </div>
        </div>

        <div className="repo-list">
          {scanning ? (
            <div style={{ padding: '20px', textAlign: 'center' }}>
              <div className="spinner" style={{ margin: '0 auto 8px' }} />
              <div className="loading-text">Scanning for repos...</div>
            </div>
          ) : repos.length === 0 ? (
            <div style={{ padding: '20px', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '13px' }}>
              No git repositories found
            </div>
          ) : (
            repos.map((repo, index) => {
              const isSelected = selectedRepos.includes(repo.path);
              return (
                <motion.div
                  key={repo.path}
                  className="repo-item"
                  onClick={() => toggleRepo(repo.path)}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.02, duration: 0.2 }}
                >
                  <div className={`repo-checkbox ${isSelected ? 'checked' : ''}`}>
                    <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M2.5 6l2.5 2.5 4.5-5" />
                    </svg>
                  </div>
                  <span className="repo-name">{repo.name}</span>
                </motion.div>
              );
            })
          )}
        </div>
      </div>
    </aside>
  );
}
