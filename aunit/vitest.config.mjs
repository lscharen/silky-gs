import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Tests live in tests/**/*.test.mjs
    include: ['tests/**/*.test.mjs', 'test/**/*.test.mjs'],
    // Each test file assembles and runs a GoldenGate binary —
    // allow up to 60 s per test.
    testTimeout: 60_000,
    // Run sequentially: GoldenGate iix is not safe to parallelize
    // (out.dat in the same directory would collide).
    pool: 'forks',
    poolOptions: { forks: { singleFork: true } },
    // Concise output; diff shows hex buffers cleanly
    reporters: ['verbose'],
  },
});
