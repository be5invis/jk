const types = require('./types');
const parser = require('./parser.js');
const util = require('util');

console.log(util.inspect(parser.parse("-- single line\n", types), {depth: null}));
