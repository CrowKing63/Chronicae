#!/usr/bin/env node
import { promises as fs } from 'fs';
import { createHash } from 'crypto';
import { dirname, relative, resolve, sep } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');
const distDir = resolve(projectRoot, 'dist');
const manifestPath = resolve(distDir, 'precache-manifest.json');

const EXCLUDED_FILES = new Set(['sw.js']);

const toPosixPath = (value) => value.split(sep).join('/');

async function ensureDistExists() {
    try {
        const stats = await fs.stat(distDir);
        if (!stats.isDirectory()) {
            throw new Error('dist exists but is not a directory');
        }
    } catch (error) {
        throw new Error(`dist directory not found. Did you run \`npm run build\`? (${error.message})`);
    }
}

async function collectFiles() {
    const files = [];

    async function walk(currentDir) {
        const entries = await fs.readdir(currentDir, { withFileTypes: true });
        for (const entry of entries) {
            if (entry.name.startsWith('.')) {
                continue;
            }
            const fullPath = resolve(currentDir, entry.name);
            if (entry.isDirectory()) {
                await walk(fullPath);
                continue;
            }
            const relPath = toPosixPath(relative(distDir, fullPath));
            if (relPath === 'precache-manifest.json' || EXCLUDED_FILES.has(relPath)) {
                continue;
            }
            const data = await fs.readFile(fullPath);
            const hash = createHash('sha256').update(data).digest('base64');
            files.push({ path: relPath, hash });
        }
    }

    await walk(distDir);
    files.sort((a, b) => a.path.localeCompare(b.path));
    return files;
}

async function writeManifest(files) {
    const versionHasher = createHash('sha256');
    for (const file of files) {
        versionHasher.update(file.path, 'utf8');
        versionHasher.update(file.hash, 'utf8');
    }
    const version = versionHasher.digest('hex').slice(0, 16);

    const manifest = {
        generatedAt: new Date().toISOString(),
        version,
        assets: files
    };

    await fs.writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    console.log(`Generated precache manifest with ${files.length} assets (version ${version}).`);
}

async function main() {
    await ensureDistExists();
    const files = await collectFiles();
    await writeManifest(files);
}

main().catch((error) => {
    console.error('Failed to generate precache manifest:', error);
    process.exit(1);
});
