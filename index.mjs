import fs from 'fs';
import { glob } from 'glob';

const BLOG_DIR = "./papero";

const files = glob.sync(`${BLOG_DIR}/**/*.json`);

let counter = 0;
for (const file of files) {
    console.log(`Processing file (${++counter}/${files.length}): ${file}`);
    const json = JSON.parse(fs.readFileSync(file, 'utf-8'));
    if (json.content === undefined || json.trail.length > 0) {
        fs.unlinkSync(file);
        continue;
    }

    const text = json.content
        .filter(item => item.type === 'text')
        .map(item => item.text)
        .filter(item => item.length > 0)
        .join("\n\n");

    if (text.length < 300) {
        fs.unlinkSync(file);
    }
}
