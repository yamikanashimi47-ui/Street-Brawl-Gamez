extends Node2D
## The fight: rounds, timer, HUD, hit sparks, win/lose.

const FighterScript = preload("res://scripts/fighter.gd")
var p1
var p2
var hud: Node2D
var round_no := 1
var wins := [0, 0]
var timer := 99.0
var phase := "intro"   # intro / fight / ko / matchend / cutscene
var phase_t := 0.0
var sparks: Array = []
var shake := 0.0
var trail1 := 100.0
var trail2 := 100.0
var banner := ""
var sub := ""
var leaving := false
var practice := false
var cutscene_name := ""
var cutscene_source = null

func _ready() -> void:
    var fighter_class = FighterScript
    if Game.selected_fighter == "ryu":
        fighter_class = preload("res://scripts/ryu.gd") if FileAccess.file_exists("res://scripts/ryu.gd") else FighterScript
    p1 = fighter_class.new()
    p2 = FighterScript.new()
    p1.pid = 1
    p2.pid = 2
    p2.is_cpu = Game.mode == "cpu"
    practice = Game.mode == "practice"
    p2.dummy = practice
    Game.paused = false
    p2.gi = Color(0.45, 0.6, 0.98)
    p2.band = Color(1.0, 0.85, 0.1)
    if p1.char_name == "KENJI" and Game.selected_fighter == "ryu":
        p1.char_name = "RYU"
        p1.gi = Color(0.9, 0.22, 0.16)
        p1.band = Color(0.95, 0.95, 0.8)
    p1.opp = p2
    p2.opp = p1
    add_child(p1)
    add_child(p2)
    p1.hit_landed.connect(_on_hit)
    p2.hit_landed.connect(_on_hit)
    p1.ultimate_triggered.connect(_on_ultimate)
    p2.ultimate_triggered.connect(_on_ultimate)
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

func _on_ultimate(who: Node, who_name: String) -> void:
    if phase == "matchend" or phase == "ko":
        return
    cutscene_source = who
    cutscene_name = who_name
    phase = "cutscene"
    phase_t = 0.0
    p1.locked = true
    p2.locked = true
    Game.paused = true

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
        "cutscene":
            if phase_t > 1.5:
                if cutscene_source != null and cutscene_source.opp != null and cutscene_source.opp.has_method("take_hit"):
                    var dir := 1 if cutscene_source.opp.position.x < cutscene_source.position.x else -1
                    cutscene_source.opp.take_hit(260, 1.2, dir, true)
                    cutscene_source.state = "win"
                phase = "fight"
                phase_t = 0.0
                Game.paused = false
                p1.locked = false
                p2.locked = false
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
