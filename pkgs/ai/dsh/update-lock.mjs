import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const [manifestPath, workDir, cacheDir] = process.argv.slice(2);
if (!manifestPath || !workDir || !cacheDir) {
  throw new Error('Usage: update-lock.mjs <source package.json> <work directory> <npm cache>');
}

const lockPath = join(dirname(fileURLToPath(import.meta.url)), 'package-lock.json');
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
delete manifest.devDependencies;
delete manifest.scripts;

const dependencyFields = ['dependencies', 'optionalDependencies', 'peerDependencies', 'peerDependenciesMeta'];
const normalize = value => JSON.stringify(value, (_, item) => {
  if (item && typeof item === 'object' && !Array.isArray(item)) {
    return Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b)));
  }
  return item;
});
const matches = root => root?.name === manifest.name && root.version === manifest.version
  && dependencyFields.every(field => normalize(root[field] ?? {}) === normalize(manifest[field] ?? {}));

const previous = existsSync(lockPath) ? readFileSync(lockPath, 'utf8') : undefined;
if (previous && matches(JSON.parse(previous).packages?.[''])) {
  console.log(`dsh ${manifest.version}: package-lock.json already matches the source`);
  process.exit(0);
}

writeFileSync(join(workDir, 'package.json'), JSON.stringify(manifest, null, 2) + '\n');
// Retain existing transitive pins that still satisfy the new release.
if (previous) writeFileSync(join(workDir, 'package-lock.json'), previous);
execFileSync('npm', [
  'install', '--package-lock-only', '--ignore-scripts', '--no-audit', '--no-fund',
  '--cache', cacheDir, '--fetch-retries=1',
], { cwd: workDir, stdio: 'inherit' });

const updated = readFileSync(join(workDir, 'package-lock.json'), 'utf8');
if (!matches(JSON.parse(updated).packages?.[''])) {
  throw new Error('Generated package-lock.json does not match the dsh release');
}
if (updated !== previous) writeFileSync(lockPath, updated);
