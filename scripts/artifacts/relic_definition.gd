extends Resource
## Shared relic data. A combat session owns any mutable effects.

enum Perk { WAR_DRUM, GUARD_SIGIL, SCRIBE_QUILL, GILDED_SEAL, WARDEN_AEGIS }

@export var id: String
@export var title: String
@export_multiline var description: String
@export var price: int
@export var perk: Perk
@export var required_rival: String
@export var requires_journey: bool
