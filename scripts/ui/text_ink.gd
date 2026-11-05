extends RefCounted
## Semantic ink for parchment cards and dark tooltips.

const PHRASES = "\\b(deal|gain|apply|heal|draw) (?:up to )?\\d+ (?:damage|block|poison|hp|cards?)\\b"
const LIGHT_PAPER = {"deal": "#862b22", "gain": "#155479", "apply": "#285524", "heal": "#14604f", "draw": "#66346f"}
const DARK_PAPER = {
	"deal": "#ffad99", "damage": "#ffad99", "attack": "#ffad99",
	"gain": "#9ed9ff", "block": "#9ed9ff", "guard": "#9ed9ff",
	"apply": "#a0e790", "poison": "#a0e790",
	"heal": "#9ce4c7", "hp": "#9ce4c7", "health": "#9ce4c7",
	"draw": "#e4baff", "tactic": "#e4baff",
	"energy": "#ffe39a", "cadence": "#ffe39a", "rewrite": "#ffe39a",
	"pattern": "#ffe39a", "patterns": "#ffe39a", "planned": "#ffe39a", "reserve": "#b8cbd4",
}
static var card_regex := RegEx.create_from_string("(?i)" + PHRASES)
static var tooltip_regex := RegEx.create_from_string("(?i)" + PHRASES + "|\\b(damage|attack|block|guard|poison|hp|health|tactic|energy|cadence|rewrite|patterns?|planned|reserve)\\b")


static func format(message: String, tooltip: bool = false) -> String:
	var pattern := tooltip_regex if tooltip else card_regex
	var ink := DARK_PAPER if tooltip else LIGHT_PAPER
	var result := ""
	var cursor := 0
	for hit in pattern.search_all(message):
		var key := hit.get_string(1)
		if key.is_empty():
			key = hit.get_string(2)
		var start := hit.get_start()
		result += message.substr(cursor, start - cursor).replace("[", "[lb]")
		result += "[color=%s]%s[/color]" % [ink[key.to_lower()], hit.get_string()]
		cursor = hit.get_end()
	return result + message.substr(cursor).replace("[", "[lb]")
