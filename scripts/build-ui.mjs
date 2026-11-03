import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

await build({ entryPoints: ['electron/renderer/workspace-entry.js'], bundle: true, outfile: 'electron/renderer/workspace.js',
  platform: 'browser', format: 'iife', target: 'chrome140', minify: true, legalComments: 'eof' });
const packages = ['codemirror', '@codemirror/autocomplete', '@codemirror/commands', '@codemirror/lang-markdown', '@codemirror/lang-html',
  '@codemirror/lang-css', '@codemirror/lang-javascript', '@codemirror/language', '@codemirror/lint', '@codemirror/search',
  '@codemirror/state', '@codemirror/view', '@lezer/common', '@lezer/highlight', '@lezer/lr', '@lezer/markdown', '@lezer/html',
  '@lezer/css', '@lezer/javascript', '@marijn/find-cluster-break', 'crelt', 'style-mod', 'w3c-keyname', 'dompurify', '@mozilla/readability'];
let notices = '';
for (const name of packages) {
  const dir = path.join('node_modules', name);
  let license;
  for (const file of ['LICENSE', 'LICENSE.txt', 'LICENSE.md']) {
    try { license = await readFile(path.join(dir, file), 'utf8'); break; } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  if (!license) throw new Error(`Missing bundled license: ${name}`);
  notices += `\n${name}\n${'='.repeat(name.length)}\n${license}\n`;
}
await mkdir('build', { recursive: true });
await writeFile('build/reader-third-party-licenses.txt', notices);
