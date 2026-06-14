#!/usr/bin/env node
/**
 * Check all exercise video URLs on R2 and report missing (404) uploads.
 *
 * Usage:
 *   node scripts/check_r2_uploads.js
 *   node scripts/check_r2_uploads.js --folder Legs
 *   node scripts/check_r2_uploads.js --export ./scripts/output/missing_r2_uploads.json
 */

require('dotenv').config();

const fs = require('fs');
const path = require('path');

const R2_PUBLIC_BASE = (process.env.R2_PUBLIC_BASE || 'https://media.reppup.app').replace(/\/$/, '');
const LOCAL_VIDEOS_DIR = process.env.LOCAL_VIDEOS_DIR
  ? path.resolve(process.env.LOCAL_VIDEOS_DIR)
  : path.resolve(__dirname, '../exercise_videos');
const CONCURRENCY = Number(process.env.R2_CHECK_CONCURRENCY || 40);

const FOLDER_TO_R2 = {
  Abdominals: 'abdominals',
  Back: 'back',
  Biceps: 'biceps',
  Calisthenics: 'calisthenics',
  Chest: 'chest',
  Forearms: 'forearms',
  Legs: 'legs',
  Powerlifting: 'powerlifting',
  Shoulders: 'shoulders',
  Stretching: 'stretching',
  Traps: 'traps',
  Triceps: 'triceps',
  Yoga: 'yoga',
};

function getArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index === process.argv.length - 1) return null;
  return process.argv[index + 1];
}

const FOLDER_ARG = getArg('--folder');
const EXPORT_PATH = getArg('--export') || path.resolve(__dirname, 'output/missing_r2_uploads.json');

function buildVideoUrl(r2Folder, filename) {
  const slug = filename.replace(/\.mp4$/i, '');
  return `${R2_PUBLIC_BASE}/exercises/videos/${r2Folder}/${slug}.mp4`;
}

function collectFiles() {
  const folders = FOLDER_ARG
    ? Object.keys(FOLDER_TO_R2).filter(
        (f) => f.toLowerCase() === FOLDER_ARG.toLowerCase(),
      )
    : Object.keys(FOLDER_TO_R2);

  if (folders.length === 0) {
    throw new Error(`Unknown folder: ${FOLDER_ARG}`);
  }

  const entries = [];
  for (const localFolder of folders) {
    const r2Folder = FOLDER_TO_R2[localFolder];
    const dir = path.join(LOCAL_VIDEOS_DIR, localFolder);
    if (!fs.existsSync(dir)) {
      console.warn(`Skipping missing local folder: ${dir}`);
      continue;
    }
    const files = fs.readdirSync(dir).filter((f) => f.toLowerCase().endsWith('.mp4'));
    for (const file of files) {
      entries.push({
        localFolder,
        r2Folder,
        filename: file,
        slug: file.replace(/\.mp4$/i, ''),
        url: buildVideoUrl(r2Folder, file),
      });
    }
  }
  return entries;
}

async function checkUrl(entry) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    let response = await fetch(entry.url, { method: 'HEAD', signal: controller.signal });
    if (response.status === 405 || response.status === 501) {
      response = await fetch(entry.url, { method: 'GET', headers: { Range: 'bytes=0-0' }, signal: controller.signal });
    }
    return {
      ...entry,
      status: response.status,
      ok: response.ok,
      missing: response.status === 404,
    };
  } catch (error) {
    return {
      ...entry,
      status: 0,
      ok: false,
      missing: false,
      error: error.name === 'AbortError' ? 'timeout' : error.message,
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function runPool(items, worker, concurrency) {
  const results = new Array(items.length);
  let index = 0;

  async function runWorker() {
    while (index < items.length) {
      const current = index;
      index += 1;
      results[current] = await worker(items[current]);
      if ((current + 1) % 200 === 0 || current + 1 === items.length) {
        process.stdout.write(`\rChecked ${current + 1}/${items.length}...`);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, runWorker));
  process.stdout.write('\n');
  return results;
}

async function main() {
  const entries = collectFiles();
  console.log(`Checking ${entries.length} URLs at ${R2_PUBLIC_BASE}`);
  console.log(`Concurrency: ${CONCURRENCY}`);

  const results = await runPool(entries, checkUrl, CONCURRENCY);

  const missing = results.filter((r) => r.missing);
  const errors = results.filter((r) => !r.ok && !r.missing);
  const ok = results.filter((r) => r.ok);

  const byFolder = {};
  for (const item of missing) {
    byFolder[item.r2Folder] = (byFolder[item.r2Folder] || 0) + 1;
  }

  console.log('\n=== Summary ===');
  console.log(`OK (uploaded):     ${ok.length}`);
  console.log(`Missing (404):     ${missing.length}`);
  console.log(`Other errors:      ${errors.length}`);

  if (missing.length > 0) {
    console.log('\nMissing by R2 folder:');
    for (const [folder, count] of Object.entries(byFolder).sort((a, b) => b[1] - a[1])) {
      console.log(`  ${folder}: ${count}`);
    }
  }

  if (errors.length > 0) {
    console.log('\nOther errors (first 10):');
    for (const item of errors.slice(0, 10)) {
      console.log(`  [${item.status || item.error}] ${item.url}`);
    }
  }

  const report = {
    checkedAt: new Date().toISOString(),
    r2PublicBase: R2_PUBLIC_BASE,
    total: results.length,
    ok: ok.length,
    missing404: missing.length,
    otherErrors: errors.length,
    missingByFolder: byFolder,
    missing,
    errors: errors.map((e) => ({
      url: e.url,
      status: e.status,
      error: e.error,
      localFolder: e.localFolder,
      slug: e.slug,
    })),
  };

  fs.mkdirSync(path.dirname(path.resolve(EXPORT_PATH)), { recursive: true });
  fs.writeFileSync(path.resolve(EXPORT_PATH), JSON.stringify(report, null, 2));

  const txtPath = path.resolve(EXPORT_PATH).replace(/\.json$/, '.txt');
  fs.writeFileSync(
    txtPath,
    missing.map((m) => `${m.r2Folder}/${m.slug}.mp4\t${m.url}`).join('\n'),
  );

  console.log(`\nWrote report: ${path.resolve(EXPORT_PATH)}`);
  console.log(`Wrote list:   ${txtPath}`);

  if (missing.length > 0) {
    console.log('\nFirst 20 missing:');
    for (const item of missing.slice(0, 20)) {
      console.log(`  ${item.r2Folder}/${item.slug}.mp4`);
    }
  }

  process.exit(missing.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
