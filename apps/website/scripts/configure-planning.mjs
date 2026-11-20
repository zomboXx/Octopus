import {writeFile} from 'node:fs/promises';
import {join} from 'node:path';

const directory = process.argv[2];
if (!directory) throw new Error('Specify the directory containing the website build.');

const input = process.env.OCTOPUS_PUBLIC_PLANNING_URL?.trim();
let endpoint = '';
if (input) {
  const url = new URL(input);
  if (url.protocol !== 'https:' || url.username || url.password ||
      url.pathname !== '/api/plans' || url.search || url.hash) {
    throw new Error('The planning URL must be an HTTPS address ending in /api/plans.');
  }
  endpoint = url.href;
}
await writeFile(join(directory, 'try', 'planning-endpoint.js'),
                `export const publicPlanningUrl = ${JSON.stringify(endpoint)};\n`);
