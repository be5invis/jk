const types = require('./types');
const parser = require('./parser.js');
const util = require('util');
const fs = require('fs');

console.log(util.inspect(parser.parse(fs.readFileSync(process.argv[2], 'utf-8'), types), {depth: null}));
