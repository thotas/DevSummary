import React, { useState, useEffect, useCallback } from 'react';
import { AnimatePresence } from 'framer-motion';
import Sidebar from './components/Sidebar';
import SummaryView from './components/SummaryView';
import LoadingState from './components/LoadingState';
import EmptyState from './components/EmptyState';
import './styles.css';

const PERIOD_OPTIONS = [
  { value: '1w', label: 'Past Week', days: 7 },
  { value: '2w', label: 'Past 2 Weeks', days: 14 },
  { value: '1m', label: 'Past Month', days: 30 },
  { value: '3m', label: 'Past 3 Months', days: 90 },
  { value: '6m', label: 'Past 6 Months', days: 180 },
  { value: '1y', label: 'Past Year', days: 365 },
];

export default function App() {
  const [theme, setTheme] = useState('light');
  const [repos, setRepos] = useState([]);
  const [selectedRepos, setSelectedRepos] = useState([]);
  const [period, setPeriod] = useState('1w');
  const [loading, setLoading] = useState(true);
  const [scanning, setScanning] = useState(true);
  const [summary, setSummary] = useState(null);
  const [commits, setCommits] = useState([]);
  const [error, setError] = useState(null);

  // Theme
  useEffect(() => {
    window.api.getTheme().then(setTheme);
    const cleanup = window.api.onThemeChanged(setTheme);
    return cleanup;
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  // Initial repo scan
  useEffect(() => {
    async function init() {
      setScanning(true);
      try {
        const paths = await window.api.getDefaultScanPaths();
        const result = await window.api.scanRepos(paths);
        if (result.success) {
          setRepos(result.data);
          setSelectedRepos(result.data.map((r) => r.path));
        } else {
          setError(result.error);
        }
      } catch (err) {
        setError(err.message);
      } finally {
        setScanning(false);
      }
    }
    init();
  }, []);

  // Fetch commits when repos or period change
  const fetchSummary = useCallback(async () => {
    if (selectedRepos.length === 0) {
      setSummary(null);
      setCommits([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const periodDays = PERIOD_OPTIONS.find((p) => p.value === period)?.days || 7;
      const since = new Date();
      since.setDate(since.getDate() - periodDays);

      const commitResult = await window.api.getCommits({
        repoPaths: selectedRepos,
        since: since.toISOString(),
      });

      if (!commitResult.success) {
        setError(commitResult.error);
        setLoading(false);
        return;
      }

      setCommits(commitResult.data);

      const summaryResult = await window.api.getSummary({
        commits: commitResult.data,
        period,
      });

      if (summaryResult.success) {
        setSummary(summaryResult.data);
      } else {
        setError(summaryResult.error);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [selectedRepos, period]);

  useEffect(() => {
    if (!scanning) {
      fetchSummary();
    }
  }, [scanning, fetchSummary]);

  const toggleRepo = (repoPath) => {
    setSelectedRepos((prev) =>
      prev.includes(repoPath)
        ? prev.filter((p) => p !== repoPath)
        : [...prev, repoPath]
    );
  };

  const selectAllRepos = () => {
    setSelectedRepos(repos.map((r) => r.path));
  };

  const deselectAllRepos = () => {
    setSelectedRepos([]);
  };

  return (
    <div className="app">
      <Sidebar
        repos={repos}
        selectedRepos={selectedRepos}
        toggleRepo={toggleRepo}
        selectAll={selectAllRepos}
        deselectAll={deselectAllRepos}
        period={period}
        setPeriod={setPeriod}
        periodOptions={PERIOD_OPTIONS}
        scanning={scanning}
      />
      <main className="main-content">
        <AnimatePresence mode="wait">
          {scanning || loading ? (
            <LoadingState key="loading" scanning={scanning} />
          ) : error ? (
            <EmptyState key="error" message={error} isError />
          ) : !summary || summary.stats.totalCommits === 0 ? (
            <EmptyState key="empty" message="No commits found for the selected period and repositories." />
          ) : (
            <SummaryView key="summary" summary={summary} commits={commits} />
          )}
        </AnimatePresence>
      </main>
    </div>
  );
}
