extends Node
## Autoload "Game": shared settings, text helper, and the stage artwork (drawn in code).

const W := 1152.0
const H := 648.0

var mode := "cpu"   # "cpu", "versus" or "practice"
var paused := false

# Chain combos: every hit must connect, then press the next button right away.
const COMBOS := [
    {"name": "ONE-TWO", "seq": ["punch", "punch"], "bonus": 3, "launch": false, "desc": "Quick double jab"},
    {"name": "KICK RUSH", "seq": ["kick", "kick"], "bonus": 5, "launch": false, "desc": "Two heavy kicks"},
    {"name": "TRIPLE STRIKE", "seq": ["punch", "punch", "kick"], "bonus": 8, "launch": false, "desc": "Jab, jab, power kick"},
    {"name": "KENJI FURY", "seq": ["punch", "punch", "kick", "kick"], "bonus": 15, "launch": true, "desc": "Launcher finisher!"},
    {"name": "RYU HADOKEN", "seq": ["punch", "punch", "kick"], "bonus": 18, "launch": false, "desc": "Ryu fireball pressure"},
    {"name": "RYU SHORYUKEN", "seq": ["punch", "kick", "punch", "kick"], "bonus": 28, "launch": true, "desc": "Dragon punch finish"},
    {"name": "RYU TATSUMAKI", "seq": ["kick", "kick", "punch", "kick"], "bonus": 24, "launch": false, "desc": "Spinning kick pressure"},
    {"name": "RYU ULTIMATE", "seq": ["punch", "kick", "punch", "punch", "kick", "punch"], "bonus": 46, "launch": true, "desc": "Street Fighter 6 finisher"},
]

func goto(path: String) -> void:
    get_tree().call_deferred("change_scene_to_file", path)

func label(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color, width: float = -1.0, center: bool = false) -> void:
    var f: Font = ThemeDB.fallback_font
    var a := HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
    ci.draw_string_outline(f, pos, s, a, width, size, int(size * 0.18) + 2, Color(0, 0, 0, 0.9))
    ci.draw_string(f, pos, s, a, width, size, color)

func ctext(ci: CanvasItem, s: String, y: float, size: int, color: Color) -> void:
    label(ci, s, Vector2(0, y), size, color, W, true)

# ---------- STAGE: "Dojo Sunset" ----------
func draw_stage(ci: CanvasItem, t: float) -> void:
    var top := Color(0.18, 0.1, 0.36)
    var bot := Color(0.98, 0.55, 0.3)
    for i in 24:
        ci.draw_rect(Rect2(0, i * 22, W, 23), top.lerp(bot, float(i) / 23.0))
    ci.draw_circle(Vector2(800, 330), 150, Color(1, 0.8, 0.5, 0.15))
    ci.draw_circle(Vector2(800, 330), 105, Color(1, 0.88, 0.58))
    ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 520), Vector2(0, 400), Vector2(160, 290), Vector2(320, 400), Vector2(520, 270), Vector2(760, 420), Vector2(930, 310), Vector2(1152, 430), Vector2(1152, 520)]), Color(0.82, 0.42, 0.18, 0.55))
    ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 520), Vector2(0, 450), Vector2(240, 380), Vector2(480, 450), Vector2(700, 400), Vector2(1000, 460), Vector2(1152, 410), Vector2(1152, 520)]), Color(0.88, 0.5, 0.3, 0.7))
    ci.draw_rect(Rect2(340, 340, 470, 190), Color(0.3, 0.08, 0.1))
    ci.draw_colored_polygon(PackedVector2Array([Vector2(285, 345), Vector2(360, 300), Vector2(790, 300), Vector2(865, 345)]), Color(0.1, 0.04, 0.07))
    ci.draw_colored_polygon(PackedVector2Array([Vector2(440, 300), Vector2(500, 248), Vector2(650, 248), Vector2(710, 300)]), Color(0.3, 0.08, 0.1))
    ci.draw_colored_polygon(PackedVector2Array([Vector2(420, 262), Vector2(490, 215), Vector2(660, 215), Vector2(730, 262)]), Color(0.1, 0.04, 0.07))
    for x in [380, 440, 700, 760]:
        ci.draw_rect(Rect2(x, 372, 26, 40), Color(0.98, 0.78, 0.3))
    ci.draw_rect(Rect2(528, 400, 94, 130), Color(0.55, 0.35, 0.12))
    ci.draw_line(Vector2(575, 400), Vector2(575, 530), Color(0.25, 0.12, 0.05), 3)
    for i in 4:
        ci.draw_rect(Rect2(342 + i * 120, 340, 12, 190), Color(0.15, 0.04, 0.06))
    ci.draw_rect(Rect2(0, 520, W, H - 520), Color(0.36, 0.22, 0.14))
    ci.draw_rect(Rect2(0, 520, W, 6), Color(0.6, 0.4, 0.25))
    for y in [548, 586, 628]:
        ci.draw_line(Vector2(0, y), Vector2(W, y), Color(0.2, 0.11, 0.07), 3)
    for i in 14:
        ci.draw_line(Vector2(i * 90 + (i % 2) * 40, 526), Vector2(i * 90 + (i % 2) * 40 - 30, H), Color(0.25, 0.14, 0.09), 2)
    for x in [150.0, 1000.0]:
        var sway: float = sin(t * 1.5 + x) * 8.0
        ci.draw_line(Vector2(x, 0), Vector2(x + sway, 115), Color(0.1, 0.05, 0.05), 3)
        ci.draw_circle(Vector2(x + sway, 140), 40, Color(1, 0.3, 0.1, 0.18))
        ci.draw_circle(Vector2(x + sway, 140), 25, Color(0.88, 0.12, 0.1))
        ci.draw_rect(Rect2(x + sway - 12, 112, 24, 6), Color(0.1, 0.05, 0.05))
    for i in 18:
        var px: float = fmod(i * 173.0 + t * 30.0 + sin(t + i) * 25.0, W)
        var py: float = fmod(i * 97.0 + t * 45.0, H)
        ci.draw_circle(Vector2(px, py), 3.0, Color(1, 0.75, 0.85, 0.85))
