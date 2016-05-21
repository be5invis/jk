const types = require('./types');
const parser = require('./parser.js');
const util = require('util');
const fs = require('fs');
const path = require('path');

function getstr(form){
	if (form instanceof Array) {
		if(form[0] instanceof types.Reference && form[0].name === '.vbt'){
			return form[1]
		} else {
			return form[1]
		}
	} else {
		return form;
	}
}
var targets = [];
var map = {};
var h_def = {
	'source': 1,
	'javascript': 1,
	'pegjs': 1,
	'js': 1
}
var h_append = {
	'append-source': 1,
	'append-javascript': 1,
	'append-pegjs': 1,
	'append-js': 1
}
function minitangle(form) {
	if (form instanceof Array) {
		if (form[0] instanceof types.Reference && form[0].name === 'tangle-target') {
			var target = getstr(form[1]).trim();
			console.log('Tangle target :', target)
			targets.push(target);
		} else if (form[0] instanceof types.Reference && form[0].name === 'input') {
			const filename = getstr(form[1]).trim();
			const ast = parser.parse(fs.readFileSync(path.resolve(path.dirname(root), filename), 'utf-8'), types);
			minitangle(ast);
		} else if(form[0] instanceof types.Reference && h_def[form[0].name]) {
			var target = getstr(form[1]).trim();
			map[target] = form[2];
		} else if(form[0] instanceof types.Reference && h_append[form[0].name]) {
			var target = getstr(form[1]).trim();
			map[target] = (map[target] || '') + form[2];
		} else {
			form.forEach(minitangle);
		}
	}
}

function crossref(target){
	var str = map[target] || '';
	return str.replace(/<<([\w \-`*]+)>>/g, function(m, $1){
		return crossref($1.trim());
	})
}

const root = process.argv[2];
const ast = parser.parse(fs.readFileSync(root, 'utf-8'), types);
minitangle(ast);

for(let target of targets){
	fs.writeFileSync(target, crossref(target));
}
