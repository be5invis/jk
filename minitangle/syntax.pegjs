{
	const Reference = options.Reference;
	const Position = options.Position;
	function isPrefix(a, b){
		return a.length <= b.length && b.slice(0, a.length) === a;
	}
	const listType = {
		"-" : new Reference('.ul'),
		"*" : new Reference('.ul'),
		"+" : new Reference('.ul'),
		"#" : new Reference('.ol')
	}
	class BlockElement {
		constructor(type, indent, leader, body) {
			this.type = type;
			this.indent = indent;
			this.leader = leader;
			this.body = body;
			this.inner = [];
		}
		organizeInneritems(){
			// scans inner items of a lineItem and deal with lists
			var stack = [[new Reference('.cons_block')]];
			var top = 0;
			for(let line of this.inner) if(line instanceof BlockElement) {
				if(line.type === BE_LIST) {
					while (top && !(isPrefix(stack[top].indent, line.indent) && stack[top].leader === line.leader)) {
						stack[top - 1].push(stack[top]);
						top -= 1;
					}
					if(stack[top].indent === line.indent && stack[top].leader === line.leader) {
						stack[top].push(line.body)
					} else {
						top += 1;
						stack[top] = [listType[line.leader], line.body];
						stack[top].indent = line.indent;
						stack[top].leader = line.leader;
					}
				} else if(line.type === BE_NORMAL) {
					while (top && !isPrefix(stack[top].indent, line.indent)) {
						stack[top - 1].push(stack[top]);
						top -= 1;
					}
					if (top) { // We stop at a list stack frame. We should push this paragraph to the last item of the list.
						var current = stack[top];
						if(current[current.length - 1] instanceof Array && current[current.length - 1][0] instanceof Reference && current[current.length - 1][0].name === '.cons_block'){
							current[current.length - 1].push(line.body)
						} else {
							current[current.length - 1] = [new Reference('.cons_block'),
								current[current.length - 1],
								line.body]
						}
					} else {
						stack[top].push(line.body);
					}
				}
			} else {
				while(top) {
					stack[top - 1].push(stack[top]);
					top--;
				}
				stack[top].push(line);
			}
			while(top) {
				stack[top - 1].push(stack[top]);
				top--;
			}
			this.body.push(stack[0])
		}
	}
	const BE_START = Symbol('BE_START');
	const BE_END = Symbol('BE_END');
	const BE_NORMAL = Symbol('BE_NORMAL');
	const BE_LIST = Symbol('BE_LIST');
	const BE_EMPTY_LINE = Symbol('BE_EMPTY_LINE');
	
	function formLine (content) {
		if(content.length === 1) return content[0]
		else return [new Reference('.cons_line')].concat(content)
	};
	var storedVerbatimTerminator;
	function formBlock(lines) {
		var stack = [new BlockElement(BE_NORMAL, null, null, [new Reference('.cons_block')])];
		var top = 0;
		for(let line of lines) {
			if(line.type === BE_START) {
				if(top && stack[top].leader === line.leader) {
					stack[top].organizeInneritems();
					stack[top - 1].inner.push(stack[top].body);
					top -= 1
				}
				top += 1;
				stack[top] = line;
			} else if (line.type === BE_END) {
				// find the recentmost line item matching line.leader
				var found = false;
				for(var k = top; k > 0; k--) {
					if(stack[k].leader === line.leader) {
						found = true;
						break;
					}
				}
				if(!found) {
					found = top;
				}
				if(top) {
					stack[top].organizeInneritems();
					stack[top - 1].inner.push(stack[top].body);
					top -= 1
				}
			} else {
				stack[top].inner.push(line);
			}
		}
		while(top) {
			stack[top].organizeInneritems();
			stack[top - 1].inner.push(stack[top].body);
			top -= 1
		}
		stack[0].organizeInneritems();
		if(stack[0].body.length === 2 && stack[0].body[0] instanceof Reference && stack[0].body[0].name === '.cons_block'){
			stack[0].body = stack[0].body[1];
		}
		return stack[0].body;
	}
	function removeTrailingLeader(form, leader) {
		var last = form[form.length - 1];
		if(last instanceof Reference && last.name === leader) {
			return form.slice(0, -1)
		} else if(last instanceof Reference && last.name.slice(-leader.length, last.name.length) === leader) {
			last.name = last.name.slice(0, -leader.length)
			return form
		} else if(last instanceof Array && last[0] instanceof Reference && (last[0].name === '.lit' || last[0].name === '.vbt')) {
			last[1] = last[1].slice(0, -leader.length);
			return form;
		} else if(last instanceof Array && last[0] instanceof Reference && last[0].name === '.cons_line') {
			form[form.length - 1] = removeTrailingLeader(last, leader);
			return form;
		} else {
			return form;
		}
	}
}

start = block

block = items:(blockElement LINE_BREAK)+ {
	return formBlock(items.map(x=>x[0]))
}
embeddedBlock = head:blockStart rear:(LINE_BREAK blockElement)* {
	return formBlock([head].concat(rear.map(x=>x[1])))
}

blockElement = emptyLineElement/verbatimBlock/verbatimLineInvoke/blockEnd/blockStart/listItem/paragraphElement

emptyLineElement = [ \t]* &LINE_BREAK {
	return new BlockElement(BE_EMPTY_LINE, null, null, null);
}
blockEnd = indent:INDENTATION leader:NORMAL_LEADER &(LINE_BREAK/"}") {
	return new BlockElement(BE_END, indent, leader, null)
}
blockStart = begins:POS indent:INDENTATION leader:NORMAL_LEADER OPTIONAL_LINE_CALL_SPACES it:linecallItems ends:POS {
	var itsSource = input.slice(begins.offset, ends.offset);
	if(itsSource.length >= leader.length * 2 && itsSource.slice(-leader.length, itsSource.length) === leader) {
		return new BlockElement(BE_START, indent, leader, removeTrailingLeader(it, leader))
	} else {
		return new BlockElement(BE_NORMAL, indent, leader, it)
	}
}


verbatimLineInvoke = begins:POS indent:INDENTATION leader:VERBATIM_LEADER OPTIONAL_LINE_CALL_SPACES it:verbatimLinecallItems ends:POS &{
	var itsSource = input.slice(begins.offset, ends.offset);
	return !(itsSource.length >= leader.length * 2 && itsSource.slice(-leader.length, itsSource.length) === leader);
} {
	return new BlockElement(BE_NORMAL, indent, leader, it)
}

verbatimBlock = h:verbatimBlockStart LINE_BREAK b:verbatimLines t:verbatimBlockEnd {
	var a = [h];
	var k = [];
	for(let item of b){
		if(typeof item === 'string'){
			k.push(item)
		} else {
			a[a.length - 1].body.push(k.join(''));
			a.push(item);
			k = [];
		}
	}
	a[a.length - 1].body.push(k.join(''));
	return formBlock(a);
}
verbatimBlockStart = begins:POS indent:INDENTATION leader:VERBATIM_LEADER OPTIONAL_LINE_CALL_SPACES it:verbatimLinecallItems ends:POS &{
	var itsSource = input.slice(begins.offset, ends.offset);
	return itsSource.length >= leader.length * 2 && itsSource.slice(-leader.length, itsSource.length) === leader;
} {
	storedVerbatimTerminator = leader;
	return new BlockElement(BE_NORMAL, indent, leader, removeTrailingLeader(it, leader));
}
verbatimLines = (verbatimLine / verbatimTranspose)*
verbatimTranspose = begins:POS indent:INDENTATION leader:VERBATIM_LEADER OPTIONAL_LINE_CALL_SPACES it:verbatimLinecallItems ends:POS &{
	if(leader != storedVerbatimTerminator) return false;
	var itsSource = input.slice(begins.offset, ends.offset);
	return itsSource.length >= leader.length * 2 && itsSource.slice(-leader.length, itsSource.length) === leader;
} {
	return new BlockElement(BE_NORMAL, indent, leader, removeTrailingLeader(it, leader));
}
verbatimLine = body:$([^\r\n]*) LINE_BREAK &{return !isPrefix(storedVerbatimTerminator, body.trim())} { return body + "\n" }
verbatimBlockEnd = indent:INDENTATION line:VERBATIM_LEADER &(LINE_BREAK/"}") & { return isPrefix(storedVerbatimTerminator, line) }

listItem = indent:INDENTATION leader:$("-" !"-" / "+" !"+" / "*") body:textline {
	return new BlockElement(BE_LIST, indent, leader, body)
}

paragraphElement = indent:INDENTATION body:textline {
	return new BlockElement(BE_NORMAL, indent, null, body)
}

textline = ![*+\-#=] content:lineCont { return content }
lineCont = content:lineitem* { return formLine(content) }

lineitem                  = invoke / lineVerbatim / textblock / lineDoubleStar / lineSingleStar / lineEscape / lineText
lineitemWithoutDoubleStar = invoke / lineVerbatim / textblock                  / lineSingleStar / lineEscape / lineText
lineitemWithoutSingleStar = invoke / lineVerbatim / textblock / lineDoubleStar                  / lineEscape / lineText

lineVerbatim = it:verbatim { return [new Reference('.verbatim'), it] }
             / it:codeSpan { return [new Reference('.codespan'), it] }
lineEscape = "\\" special:[+#\-=`*:\[\]\{\}\\] { return [new Reference('.lit'), special]}
           / '\\' normal:[^\r\n] { return [new Reference('.lit'), '\\' + normal] }

lineText "Text" = t:$([^\r\n\[\{\\\}\]*`]+) { return [new Reference('.lit'), t] }
lineDoubleStar = "**" inner:lineitemWithoutDoubleStar* "**" { return [new Reference('.inline**'), formLine(inner)] }
lineSingleStar = "*" !"*" inner:lineitemWithoutSingleStar* "*" { return [new Reference('.inline*'), formLine(inner)] }

expression
	= invoke / quote / verbatim / textblock / parting / literal
textblock
	= "{" inside:(textline / embeddedBlock) "}" {
		return inside
	}
expressionitems
	= head:expression rear:(OPTIONAL_EXPRESSION_SPACES expression)* tail:(OPTIONAL_EXPRESSION_SPACES ":" lineCont)? {
		var res = [head]
		for(var j = 0; j < rear.length; j++){
			res.push(rear[j][1])
		};
		if(tail){
			res.push(tail[2]);
		}
		return res;
	}
linecallItems
	= head:expression rear:(OPTIONAL_LINE_CALL_SPACES expression)* tail:(OPTIONAL_LINE_CALL_SPACES ":" lineCont)? {
		var res = [head]
		for(var j = 0; j < rear.length; j++){
			res.push(rear[j][1])
		};
		if(tail) {
			res.push(tail[2]);
		}
		return res;
	}

verbatimLinecallItems
	= head:expression rear:(OPTIONAL_LINE_CALL_SPACES expression)* tail:(OPTIONAL_LINE_CALL_SPACES ":" $([^\r\n]+))? {
		var res = [head]
		for(var j = 0; j < rear.length; j++){
			res.push(rear[j][1])
		};
		if(tail) {
			res.push([new Reference('.vbt'), tail[2]]);
		}
		return res;
	}

invoke
	= begins:POS "["
	  OPTIONAL_EXPRESSION_SPACES
	  inside:expressionitems
	  OPTIONAL_EXPRESSION_SPACES
	  "]" ends:POS {
		var res = inside.slice(0);
		Object.defineProperty(res, 'begins', {
			value: begins,
			enumerable: false
		});
		Object.defineProperty(res, 'ends', {
			value: ends,
			enumerable: false
		});
		return res;
	}
quote
	= "'" it:(invoke/verbatim/textblock/identifier) { return [new Reference('quote'), it] }
literal
	= numberliteral
	/ stringliteral

parting
	= head:(invoke/quote/identifier) rear:(("." identifier)*) {
		var form = head;
		if(rear) for(var j = 0; j < rear.length; j++){
			form = ['.', form, rear[j][1].name]
		}
		return form;
	}

/* Tokens */
stringliteral "String Literal"
	= "\"" inner:stringcharacter* "\"" { return inner.join('') }
stringcharacter
	= [^"\\\r\n]
	/ "\\u" digits:([a-fA-F0-9] [a-fA-F0-9] [a-fA-F0-9] [a-fA-F0-9]) { 
		return String.fromCharCode(parseInt(digits.join(''), 16))
	}
	/ "\\" which:[^u\r\n] {
		switch(which) {
			case('n'): return "\n"
			case('r'): return "\r"
			case('"'): return "\""
			case('t'): return "\t"
			case('v'): return "\v"
			default: return "\\" + which
		}
	}
	/ "\\" NEWLINE "\\" { return '' }

codeSpan "Code Span"
	= "`" val:$([^`]+) "`" { return val }
	/ terminator:$("`" "`"+) & { storedVerbatimTerminator = terminator; return true }
	  inner: $(codeSpanInner*)
	  codeSpanTerminator { return inner }
codeSpanInner
	= [^`]+
	/ !codeSpanTerminator "`"
codeSpanTerminator
	= term:$("`" "`"+) & { term === storedVerbatimTerminator } { return }
verbatim "Verbatim Segment"
	= "{:" val:$(([^:] / ":"+ [^:\}])*) ":}" { return val }
	/ "{" terminator:verbatimEqualSequence ":" & { storedVerbatimTerminator = terminator; return true }
		inner:$(verbatimInner*)
		verbatimTerminator { return inner }
verbatimInner
	= content:$([^:]+) { return content }
	/ !verbatimTerminator content:":" { return content }
verbatimTerminator
	= ":" terminator:verbatimEqualSequence "}" & { 
		return terminator === storedVerbatimTerminator
	} { return }
verbatimEqualSequence
	= equals:$("="+) { return equals }
numberliteral "Numeric Literal"
	= "-" positive:numberliteral { return -positive }
	/ ("0x" / "0X") hexdigits:$([0-9a-fA-F]+) { return parseInt(hexdigits, 16) }
	/ decimal:$([0-9]+ ("." [0-9]+)? ([eE] [+\-]? [0-9]+)?) { return decimal - 0 }
identifier "Identifier"
	= begins:POS it:$([a-zA-Z\-_/+*<=>!?$%_&~^@#] [a-zA-Z0-9\-_/+*<=>!?$%_&~^@#]*) ends:POS {
		var ref = new Reference(it);
		Object.defineProperty(ref, 'begins', {
			value: begins,
			enumerable: false
		});
		Object.defineProperty(ref, 'ends', {
			value: ends,
			enumerable: false
		});
		return ref;
	}

NORMAL_LEADER = $("-" "-"+) / $("+" "+"+)
VERBATIM_LEADER = $("=" "="+)
INDENTATION = $([ \t]*)

LINE_BREAK "Line Break"
	= "\r"? "\n" 
NEWLINE
	= LINE_BREAK SPACE_CHARACTER_OR_NEWLINE*
EXPRESSION_SPACE
	= SPACE_CHARACTER_OR_NEWLINE
	/ COMMENT
OPTIONAL_EXPRESSION_SPACES
	= $(EXPRESSION_SPACE*)
OPTIONAL_LINE_CALL_SPACES
	= $(SPACE_CHARACTER*)
SPACE_CHARACTER_OR_NEWLINE "Space Character or Newline"
	= [\t\v\f \u00A0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\uFEFF\r\n]
COMMENT "Comment"
	= $(";" [^\r\n]* LINE_BREAK)
SPACES "Space without Newline"
	= $(SPACE_CHARACTER+)
SPACE_CHARACTER "Space Character"
	= [\t\v\f \u00A0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\uFEFF]

POS = "" { return new Position(null, offset()) }
