class Reference {
	constructor(name) {
		this.name = name;
	}
}
class Position {
	constructor(source, offset) {
		this.source = source;
		this.offset = offset;
	}
}

exports.Reference = Reference;
exports.Position = Position;
