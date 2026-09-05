const fs = require('node:fs');
const path = require('node:path');
const files = ['index.html','finance-v2.css','finance-navigation.js','manifest.json','sw.js','icon.svg'];
const output = path.join(__dirname, 'dist');
fs.mkdirSync(output, {recursive:true});
const unknown = fs.readdirSync(output).filter(name => !files.includes(name));
if (unknown.length) throw new Error('Unexpected files in dist. Inspect this directory before publishing.');
for (const file of files) fs.copyFileSync(path.join(__dirname,file),path.join(output,file));
console.log(`Built ${files.length} public files. No scripts, database exports or environment files included.`);
