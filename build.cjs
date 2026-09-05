const fs = require('node:fs');
const path = require('node:path');
const files = ['index.html','finance-v2.css','finance-navigation.js','manifest.json','sw.js','icon.svg'];
const output = path.join(__dirname, 'dist');
fs.mkdirSync(output, {recursive:true});
// dist is generated output, never source data. Clean stale build artifacts so
// Netlify cannot publish an old bundle or fail on files from a previous build.
for (const name of fs.readdirSync(output)) {
  fs.rmSync(path.join(output, name), {recursive:true, force:true});
}
for (const file of files) fs.copyFileSync(path.join(__dirname,file),path.join(output,file));
console.log(`Built ${files.length} public files. No scripts, database exports or environment files included.`);
