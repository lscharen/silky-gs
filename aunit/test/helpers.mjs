/**
 * aunit/test/helpers.mjs — shared test utilities
 *
 * Re-exports the effective tool paths (env-var or default) so tests can
 * display them in skip messages, and exposes boolean skip flags for use
 * with vitest's describe.skipIf / test.skipIf.
 */
import { existsSync } from 'node:fs';

export const IIX_PATH    = process.env.AUNIT_IIX      ?? 'C:\\Program Files (x86)\\GoldenGate\\iix.exe';
export const MERLIN_PATH = process.env.AUNIT_MERLIN32 ?? 'C:\\Programs\\IIgsXDev\\bin\\Merlin32-BD-1.1.0.exe';

export const hasIix    = existsSync(IIX_PATH);
export const hasMerlin = existsSync(MERLIN_PATH) && hasIix;
