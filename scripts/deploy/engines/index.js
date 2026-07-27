/**
 * Deploy engine registry.
 *
 * Each engine exports a uniform interface:
 *   - name: string
 *   - deploy(chain, options): Promise<{ success, chain, ... }>
 *   - buildCommand(chain, options): string
 *
 * Register new engines here; reference them by `name` from scripts/config/deploy.config.js.
 */
const foundry = require('./foundryEngine');
const hardhatZksync = require('./hardhatZksyncEngine');
const tron = require('./tronEngine');

const ENGINES = {
  [foundry.name]: foundry,
  [hardhatZksync.name]: hardhatZksync,
  [tron.name]: tron,
};

/**
 * @param {string} name - engine name (e.g. 'foundry', 'hardhat-zksync')
 * @returns {{name: string, deploy: Function, buildCommand: Function}}
 */
function getEngine(name) {
  const engine = ENGINES[name];
  if (!engine) {
    throw new Error(`Unknown deploy engine "${name}". Available: ${Object.keys(ENGINES).join(', ')}`);
  }
  return engine;
}

module.exports = { ENGINES, getEngine };
