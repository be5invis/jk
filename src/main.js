const types = require('./types');
const parser = require('./parser.js');
const util = require('util');

console.log(util.inspect(parser.parse("{xxx [obj.method]{text} [obj] xxx}", types), {depth: null}));
