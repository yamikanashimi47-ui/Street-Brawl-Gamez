extends Node2D
## The fight: rounds, timer, HUD, hit sparks, win/lose.

const FighterScript = preload("res://scripts/fighter.gd")
var p1
var p2
var hud: Node2D
var round_no := 1
var wins := [0, 0]
var timer := 99.0
var phase := "intro"   # intro / fight / ko / matchend
var phase_t := 0.0
var sparks: Array = []
var shake := 0.0
var trail1 := 100.0
var trail2 := 100.0
var banner := ""
var sub := ""
var leaving := false
var practice := false

func _ready() -> void:
    p1 = FighterScript.new()
    p2 = FighterScript.new()
    p1.pid = 1
    p2.pid = 2
    p2.is_cpu = Game.mode == "cpu"
    practice = Game.mode == "practice"
    p2.dummy = practice
    Game.paused = false
    p2.gi = Color(0.45, 0.6, 0.98)
    p2.band = Color(1.0, 0.85, 0.1)
    p1.opp = p2
    p2.opp = p1
    add_child(p1)
    add_child(p2)
    p1.hit_landed.connect(_on_hit)
    p2.hit_landed.connect(_on_hit)
    hud = Node2D.new()
    add_child(hud)
    hud.draw.connect(_draw_hud)
    _start_round()

func _start_round() -> void:
    p1.reset_fighter(330.0, 1)
    p2.reset_fighter(822.0, -1)
    trail1 = 100.0
    trail2 = 100.0
    timer = 99.0
    phase = "intro"
    phase_t = 0.0
    if practice:
        phase = "fight"
        p1.locked = false
        p2.locked = false

func _on_hit(pos: Vector2, blocked: bool) -> void:
    sparks.append({"pos": pos, "t": 0.0, "b": blocked})
    shake = 2.0 if blocked else 7.0

func _end_round() -> void:
    phase = "ko"
    phase_t = 0.0
    p1.locked = true
    p2.locked = true
    var w := 0
    if p1.hp > p2.hp:
        w = 1
    elif p2.hp > p1.hp:
        w = 2
    banner = "K.O." if (p1.hp <= 0 or p2.hp <= 0) else "TIME UP"
    sub = ""
    if w == 0:
        banner = "DRAW"
    else:
        wins[w - 1] += 1
        var winner = p1 if w == 1 else p2
        if winner.state != "ko":
            winner.state = "win"
        sub = _tag(w) + " WINS"

func _tag(i: int) -> String:
    if i == 1:
        return "P1"
    if practice:
        return "DUMMY"
    return "CPU" if Game.mode == "cpu" else "P2"

func _physics_process(delta: float) -> void:
    if Game.paused:
        hud.queue_redraw()
        return
    phase_t += delta
    match phase:
        "intro":
            if phase_t > 2.0:
                phase = "fight"
                phase_t = 0.0
                p1.locked = false
                p2.locked = false
        "fight":
            if practice:
                _practice_tick(delta)
            else:
                timer -= delta
                if p1.hp <= 0 or p2.hp <= 0 or timer <= 0.0:
                    timer = maxf(timer, 0.0)
                    _end_round()
        "ko":
            if phase_t > 3.0:
                if wins[0] >= 2 or wins[1] >= 2:
                    phase = "matchend"
                    phase_t = 0.0
                else:
                    round_no += 1
                    _start_round()
        "matchend":
            if phase_t > 1.0 and (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_SPACE)) and not leaving:
                leaving = true
                Game.goto("res://scenes/main_menu.tscn")
    # keep fighters from overlapping
    if p1.position.y > 540.0 and p2.position.y > 540.0:
        var dx: float = p2.position.x - p1.position.x
        if absf(dx) < 56.0:
            var push: float = (56.0 - absf(dx)) * 0.5
            var sgn := 1.0 if dx >= 0.0 else -1.0
            p1.position.x -= push * sgn
            p2.position.x += push * sgn
    trail1 = move_toward(trail1, float(p1.hp), 25.0 * delta)
    trail2 = move_toward(trail2, float(p2.hp), 25.0 * delta)
    for s in sparks:
        s["t"] += delta
    sparks = sparks.filter(func(s): return s["t"] < 0.25)
    shake = maxf(0.0, shake - 40.0 * delta)
    position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.1 else Vector2.ZERO
    queue_redraw()
    hud.queue_redraw()

func _draw() -> void:
    Game.draw_stage(self, Time.get_ticks_msec() / 1000.0)

# ---------- HUD ----------
func _bar(x: float, from_right: bool, hp_now: float, hp_trail: float) -> void:
    var w := 440.0
    hud.draw_rect(Rect2(x - 5, 35, w + 10, 38), Color(0, 0, 0, 0.9))
    hud.draw_rect(Rect2(x, 40, w, 28), Color(0.3, 0.04, 0.04))
    var tw: float = w * hp_trail / 100.0
    var hw: float = w * hp_now / 100.0
    if from_right:
        hud.draw_rect(Rect2(x + w - tw, 40, tw, 28), Color(0.9, 0.2, 0.1))
        hud.draw_rect(Rect2(x + w - hw, 40, hw, 28), Color(1.0, 0.85, 0.1))
    else:
        hud.draw_rect(Rect2(x, 40, tw, 28), Color(0.9, 0.2, 0.1))
        hud.draw_rect(Rect2(x, 40, hw, 28), Color(1.0, 0.85, 0.1))

func _draw_hud() -> void:
    _bar(60.0, false, float(p1.hp), trail1)
    _bar(652.0, true, float(p2.hp), trail2)
    Game.label(hud, _tag(1) + " KENJI", Vector2(60, 108), 24, Color.WHITE, 440, true)
    Game.label(hud, _tag(2) + " KENJI", Vector2(652, 108), 24, Color.WHITE, 440, true)
    for i in (0 if practice else 2):
        hud.draw_circle(Vector2(75 + i * 24, 128), 8, Color(1, 0.85, 0.1) if wins[0] > i else Color(0.25, 0.25, 0.3))
        hud.draw_circle(Vector2(1077 - i * 24, 128), 8, Color(1, 0.85, 0.1) if wins[1] > i else Color(0.25, 0.25, 0.3))
    hud.draw_rect(Rect2(526, 32, 100, 66), Color(0, 0, 0, 0.9))
    Game.label(hud, "--" if practice else str(int(ceil(timer))), Vector2(526, 86), 48, Color.WHITE, 100, true)
    # hit sparks
    for s in sparks:
        var k: float = s["t"] / 0.25
        var col := Color(0.4, 0.7, 1.0) if s["b"] else Color(1.0, 0.9, 0.3)
        for i in 8:
            var a: float = i * PI / 4.0 + 0.3
            var d := Vector2(cos(a), sin(a))
            hud.draw_line(s["pos"] + d * (8.0 + k * 20.0), s["pos"] + d * (22.0 + k * 40.0), col, 5.0 * (1.0 - k) + 1.0)
    # banners
    match phase:
        "intro":
            if phase_t < 1.2:
                Game.ctext(hud, "ROUND %d" % round_no, 320, 100, Color(1.0, 0.85, 0.1))
            else:
                Game.ctext(hud, "FIGHT!", 320, 130, Color(0.95, 0.15, 0.15))
            Game.ctext(hud, "P1: A/D move  W jump  F punch  G kick        P2: Arrows  K punch  L kick", 600, 18, Color(0.95, 0.95, 0.95))
            Game.ctext(hud, "Hold back to BLOCK  -  chain hits for combos  -  ESC / P: pause + combo list", 626, 18, Color(0.95, 0.95, 0.95))
        "ko":
            Game.ctext(hud, banner, 320, 140, Color(0.95, 0.15, 0.15))
            Game.ctext(hud, sub, 400, 52, Color.WHITE)
        "matchend":
            var who := _tag(1) if wins[0] >= 2 else _tag(2)
            Game.ctext(hud, who + " WINS THE MATCH!", 300, 80, Color(1.0, 0.85, 0.1))
            if int(phase_t * 2.0) % 2 == 0:
                Game.ctext(hud, "PRESS ENTER", 400, 40, Color.WHITE)
    _draw_combos()
    if practice:
        _draw_practice_hud()
    if Game.paused:
        _draw_pause()

# ---------- INPUT: pause + practice keys ----------
func _input(e: InputEvent) -> void:
    var ke := e as InputEventKey
    if ke == null or not ke.pressed or ke.echo:
        return
    var k: int = ke.keycode
    if Game.paused:
        _pause_input(k)
    elif k == KEY_ESCAPE or k == KEY_P:
        if phase != "matchend":
            Game.paused = true
            pause_sel = 0
            pause_page = "menu"
    elif practice and k == KEY_R:
        _practice_reset()
    elif practice and k == KEY_B:
        p2.dummy_block = not p2.dummy_block

const PAUSE_ITEMS := ["RESUME", "COMBO LIST", "RESTART", "QUIT TO MENU"]
var pause_sel := 0
var pause_page := "menu"
var heal_t := 0.0
var ko_t := 0.0
var max_combo := 0

func _pause_input(k: int) -> void:
    var confirm: bool = k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
    if pause_page == "combos":
        if confirm or k == KEY_ESCAPE:
            pause_page = "menu"
        return
    if k == KEY_UP or k == KEY_W:
        pause_sel = (pause_sel + PAUSE_ITEMS.size() - 1) % PAUSE_ITEMS.size()
    elif k == KEY_DOWN or k == KEY_S:
        pause_sel = (pause_sel + 1) % PAUSE_ITEMS.size()
    elif k == KEY_ESCAPE or k == KEY_P:
        Game.paused = false
    elif confirm:
        match pause_sel:
            0:
                Game.paused = false
            1:
                pause_page = "combos"
            2:
                Game.paused = false
                Game.goto("res://scenes/fight.tscn")
            3:
                Game.paused = false
                Game.goto("res://scenes/main_menu.tscn")

# ---------- PRACTICE MODE ----------
func _practice_reset() -> void:
    p1.reset_fighter(330.0, 1)
    p2.reset_fighter(822.0, -1)
    p1.locked = false
    p2.locked = false
    trail1 = 100.0
    trail2 = 100.0
    max_combo = 0

func _practice_tick(delta: float) -> void:
    if p2.state == "ko":
        ko_t += delta
        if ko_t > 1.5:
            ko_t = 0.0
            var fx: float = clampf(p2.position.x, 120.0, 1030.0)
            p2.reset_fighter(fx, 1 if p1.position.x > fx else -1)
            p2.locked = false
            trail2 = 100.0
    elif p2.hp < 100 and (p2.state == "idle" or p2.state == "walk"):
        heal_t += delta
        if heal_t > 2.0:
            p2.hp = 100
            heal_t = 0.0
    else:
        heal_t = 0.0
    max_combo = maxi(max_combo, p1.combo_hits)

func _draw_practice_hud() -> void:
    Game.ctext(hud, "PRACTICE MODE", 175, 30, Color(0.6, 0.9, 1.0))
    Game.ctext(hud, "BEST COMBO: %d HITS" % max_combo, 205, 22, Color.WHITE)
    Game.ctext(hud, "R: reset    B: dummy block [%s]    ESC / P: pause + combo list" % ("ON" if p2.dummy_block else "OFF"), 630, 20, Color(0.95, 0.95, 0.95))

func _draw_combos() -> void:
    var fs := [p1, p2]
    for i in 2:
        var f = fs[i]
        if f.combo_show > 0.0 and f.combo_hits >= 2:
            var x: float = 60.0 if i == 0 else 652.0
            Game.label(hud, "%d HITS!" % f.combo_hits, Vector2(x, 270), 60, Color(1.0, 0.85, 0.1), 440, true)
            if f.combo_name != "":
                Game.label(hud, f.combo_name, Vector2(x, 312), 34, Color(1.0, 0.35, 0.2), 440, true)
            Game.label(hud, "%d DMG" % f.combo_dmg, Vector2(x, 346), 26, Color.WHITE, 440, true)

# ---------- PAUSE MENU ----------
func _draw_pause() -> void:
    hud.draw_rect(Rect2(0, 0, Game.W, Game.H), Color(0, 0, 0, 0.7))
    if pause_page == "menu":
        Game.ctext(hud, "PAUSED", 200, 96, Color(1.0, 0.85, 0.1))
        for i in PAUSE_ITEMS.size():
            var y: float = 320.0 + i * 58.0
            if i == pause_sel:
                var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 120.0)
                Game.ctext(hud, "> " + PAUSE_ITEMS[i] + " <", y, 38, Color(1.0, 0.85 * pulse, 0.1))
            else:
                Game.ctext(hud, PAUSE_ITEMS[i], y, 34, Color(0.92, 0.92, 0.92))
        Game.ctext(hud, "W/S or Up/Down: move    ENTER: select    ESC: resume", 620, 20, Color(0.85, 0.85, 0.85))
    else:
        Game.ctext(hud, "KENJI  -  COMBO LIST", 100, 50, Color(1.0, 0.85, 0.1))
        hud.draw_rect(Rect2(90, 125, 972, 470), Color(0.08, 0.08, 0.18, 0.95))
        for i in Game.COMBOS.size():
            var c: Dictionary = Game.COMBOS[i]
            var y: float = 180.0 + i * 78.0
            var k1: Array = []
            var k2: Array = []
            for m in c["seq"]:
                k1.append("F" if m == "punch" else "G")
                k2.append("K" if m == "punch" else "L")
            Game.label(hud, str(c["name"]), Vector2(120, y), 32, Color(1.0, 0.85, 0.1))
            Game.label(hud, str(c["desc"]), Vector2(120, y + 26), 18, Color(0.8, 0.8, 0.9))
            Game.label(hud, " > ".join(c["seq"].map(func(m): return str(m).to_upper())), Vector2(470, y), 28, Color.WHITE)
            Game.label(hud, "P1: %s      P2: %s" % [" ".join(k1), " ".join(k2)], Vector2(470, y + 26), 18, Color(0.8, 0.8, 0.9))
            Game.label(hud, "+%d DMG" % int(c["bonus"]), Vector2(900, y), 26, Color(1.0, 0.4, 0.3))
        Game.ctext(hud, "HOW: land a hit, then press the next button right away - before the enemy recovers.", 530, 20, Color.WHITE)
        Game.ctext(hud, "Blocked or missed attacks break the chain.   Max 4 hits.", 560, 20, Color(0.85, 0.85, 0.95))
        Game.ctext(hud, "ESC / ENTER: back", 628, 20, Color(0.85, 0.85, 0.85))
