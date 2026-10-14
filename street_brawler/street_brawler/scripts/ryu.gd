extends "res://scripts/fighter.gd"

signal ultimate_triggered(who, name)

# Simple Ryu subclass: sets name/colors, registers a few Ryu combos, and
# provides a test ultimate trigger (press U) which emits `ultimate_triggered`.
# The fight.gd file listens for that signal and runs the cutscene.

var prev_ult_pressed := false

func _ready() -> void:
    # appearance / name
    char_name = "RYU"
    gi = Color(0.9, 0.22, 0.16)
    band = Color(0.95, 0.95, 0.8)

    # register Ryu combos into Game.COMBOS if they're not already present
    var existing := Game.COMBOS.map(func(c): return str(c["name"]))
    var ryu_combos := [
        {"name": "RYU HADOKEN", "seq": ["punch", "punch", "kick"], "bonus": 18, "launch": false, "desc": "Ryu fireball pressure"},
        {"name": "RYU SHORYUKEN", "seq": ["punch", "kick", "punch"], "bonus": 28, "launch": true, "desc": "Dragon punch finish"},
        {"name": "RYU TATSUMAKI", "seq": ["kick", "kick", "punch", "kick"], "bonus": 24, "launch": false, "desc": "Spinning kick barrage"},
    ]
    for c in ryu_combos:
        if not c["name"] in existing:
            Game.COMBOS.append(c)

    # ensure node is processing so _process is called
    set_process(true)

# Use _process to detect a test-ultimate input so we don't override the
# existing fighter._physics_process. Pressing 'U' will emit the ultimate
# signal once per press.
func _process(delta: float) -> void:
    var u_pressed := Input.is_physical_key_pressed(KEY_U)
    if u_pressed and not prev_ult_pressed:
        emit_signal("ultimate_triggered", self, char_name)
    prev_ult_pressed = u_pressed
