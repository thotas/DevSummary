import React from 'react';
import { motion } from 'framer-motion';

export default function LoadingState({ scanning }) {
  return (
    <motion.div
      className="loading-container"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="spinner" />
      <div className="loading-text">
        {scanning ? 'Scanning for repositories...' : 'Analyzing your commits...'}
      </div>
    </motion.div>
  );
}
