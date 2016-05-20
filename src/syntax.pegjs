{
	class LineItem {
		constructor(type, indent, leader, body){
			this.type = type;
			this.indent = indent;
			this.leader = leader;
			this.body = body;
		}
	}
	const LINE_START = Symbol('LINE_START');
	const LINE_END = Symbol('LINE_END');
	const LINE_NORMAL = Symbol('LINE_NORMAL');
	const LINE_UL = Symbol('LINE_UL');
	const LINE_OL = Symbol('LINE_OL');
	
	const Reference = options.Reference;
	const Position = options.Position;
	const formLine = function(content) {
		if(content.length === 1) return content[0]
		else return [new Reference('.cons_line')].concat(content)
	};
	const formBlock = function(content) {
		if(content.length === 1) return content[0]
		else return [new Reference('.cons_block')].concat(content)
	};
	var storedVerbatimTerminator;
	var nVerbatimTests = 0;
	var textIndentStack = [];
	var textIndent = "";
}

start = x:blockElement NEWLINE { return x }

blockElement = verbatimBlock / verbatimLineInvoke/blockEnd/blockStart/listItem/paragraph

blockEnd = indent:indentation leader:normalLeader &NEWLINE {
	return new LineItem(LINE_END, indent, leader, null)
}
blockStart = indent:indentation leader:normalLeader OPTIONAL_LINE_CALL_SPACES it:linecallItems {
	if(it[it.length - 1] instanceof Reference && it[it.length - 1].name === leader){
		return new LineItem(LINE_START, indent, leader, it.slice(0, -1))
	} else {
		return new LineItem(LINE_NORMAL, indent, leader, it)
	}
}


verbatimLineInvoke = indent:indentation leader:verbatimLeader OPTIONAL_LINE_CALL_SPACES it:verbatimExpressionItems tail:(OPTIONAL_LINE_CALL_SPACES ":" $([^\r\n]+)) {
	return new LineItem(LINE_NORMAL, indent, leader, it.concat([tail[2]]))
}

verbatimBlock = h:verbatimBlockStart NEWLINE b:verbatimLines t:verbatimBlockEnd {
	h.body.push(b.join(''));
	return h;
}
verbatimBlockStart = indent:indentation leader:verbatimLeader OPTIONAL_LINE_CALL_SPACES it:verbatimExpressionItems
	&{return (it[it.length - 1] instanceof Reference && it[it.length - 1].name === leader)} {
		storedVerbatimTerminator = leader;
		return new LineItem(LINE_NORMAL, leader, it);
	}
verbatimLines = verbatimLine*
verbatimLine = body:$([^\r\n]*) NEWLINE &{return body !== storedVerbatimTerminator} { return body + "\n" }
verbatimBlockEnd = trailer:verbatimLeader & { return trailer == storedVerbatimTerminator }

listItem = indent:indentation leader:$("-" !"-" / "*") body:line {
	return new LineItem(LINE_NORMAL, indent, leader, body)
}

paragraph = indent:indentation line {
	return new LineItem(LINE_NORMAL, indent, null, body)
}

expression
	= invoke / quote / verbatim / textblock / parting / literal
textblock
	= "{" inside:line "}" {
		return inside
	}

line = ![*+\-#=] content:lineitem* { return formLine(content) }

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


expressionitems
	= head:expression rear:(OPTIONAL_EXPRESSION_SPACES expression)* tail:(OPTIONAL_EXPRESSION_SPACES ":" line)? {
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
	= head:expression rear:(OPTIONAL_EXPRESSION_SPACES expression)* tail:(OPTIONAL_EXPRESSION_SPACES ":" line)? {
		var res = [head]
		for(var j = 0; j < rear.length; j++){
			res.push(rear[j][1])
		};
		if(tail){
			res.push(tail[2]);
		}
		return res;
	}
verbatimExpressionItems = head:expression rear:(OPTIONAL_LINE_CALL_SPACES expression)* {
	var res = [head]
	for(var j = 0; j < rear.length; j++){
		res.push(rear[j][1])
	};
	return res;
}
invoke
	= begins:POS "["
	  OPTIONAL_EXPRESSION_SPACES
	  inside:expressionitems
	  OPTIONAL_EXPRESSION_SPACES
	  "]" ends:POS {
		var call = inside.slice(0);
		Object.defineProperty(call, 'begins', {
			value: begins,
			enumerable: false
		});
		Object.defineProperty(call, 'ends', {
			value: ends,
			enumerable: false
		});
		return call
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

normalLeader = $("-" "-"+) / $("+" "+"+)
verbatimLeader = $("=" "="+)
indentation = $([ \t]*)

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

POS = "" { return new Position(offset()) }
