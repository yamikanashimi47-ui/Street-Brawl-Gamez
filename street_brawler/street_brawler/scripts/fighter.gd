extends Node2D
## A fighter ("KENJI"). The whole character is drawn with code, so there are no image files.

signal hit_landed(pos: Vector2, blocked: bool)

const SPEED := 270.0
const JUMP_V := -820.0
const GRAV := 2200.0
const FLOOR_Y := 560.0
const ATK := {
    "punch": {"total": 0.32, "start": 0.08, "end": 0.18, "dmg": 8, "reach": 95.0, "top": 150.0, "h": 50.0, "stun": 0.36},
    "kick": {"total": 0.48, "start": 0.16, "end": 0.28, "dmg": 13, "reach": 125.0, "top": 105.0, "h": 70.0, "stun": 0.42},
}

var pid := 1
var is_cpu := false
var opp = null
var facing := 1
var hp := 100
var vel := Vector2.ZERO
var state := "idle"   # idle walk jump punch kick hit ko win
var attack := ""
var st_time := 0.0
var did_hit := false
var blocking := false
var stun := 0.0
var anim := 0.0
var locked := true
var zoom := 1.0
var gi := Color(0.95, 0.95, 0.95)
var band := Color(0.9, 0.12, 0.15)
var ai_t := 0.0
var ai_act := "idle"
var dummy := false          # practice-mode dummy: stands still
var dummy_block := false
var prev_p := false
var prev_k := false
var want_p := false
var want_k := false
var chain: Array = []
var chain_t := 0.0
var combo_hits := 0
var combo_dmg := 0
var combo_show := 0.0
var combo_name := ""

func reset_fighter(x: float, f: int) -> void:
    position = Vector2(x, FLOOR_Y)
    vel = Vector2.ZERO
    hp = 100
    state = "idle"
    attack = ""
    stun = 0.0
    blocking = false
    locked = true
    facing = f
    ai_act = "idle"
    chain.clear()
    combo_hits = 0
    combo_dmg = 0
    combo_show = 0.0
    combo_name = ""

func hurtbox() -> Rect2:
    return Rect2(position.x - 32.0, position.y - 170.0, 64.0, 170.0)

# ---------- INPUT ----------
func _human_input() -> Dictionary:
    var k: Array = [KEY_A, KEY_D, KEY_W, KEY_F, KEY_G] if pid == 1 else [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_K, KEY_L]
    return {
        "left": Input.is_physical_key_pressed(k[0]),
        "right": Input.is_physical_key_pressed(k[1]),
        "up": Input.is_physical_key_pressed(k[2]),
        "punch": Input.is_physical_key_pressed(k[3]),
        "kick": Input.is_physical_key_pressed(k[4]),
    }

func _cpu_input(delta: float) -> Dictionary:
    var inp := {"left": false, "right": false, "up": false, "punch": false, "kick": false}
    ai_t -= delta
    if ai_t <= 0.0:
        ai_t = randf_range(0.15, 0.45)
        var dist: float = absf(opp.position.x - position.x)
        var r := randf()
        if dist > 150.0:
            ai_act = "approach" if r < 0.88 else "jump"
        elif dist > 105.0:
            ai_act = "kick" if r < 0.35 else ("approach" if r < 0.7 else "block")
        else:
            if r < 0.3:
                ai_act = "punch"
            elif r < 0.5:
                ai_act = "kick"
            elif r < 0.78:
                ai_act = "block"
            else:
                ai_act = "retreat"
        if (opp.state == "punch" or opp.state == "kick") and dist < 150.0 and randf() < 0.5:
            ai_act = "block"
    var to_right: bool = facing == 1
    match ai_act:
        "approach":
            inp["right"] = to_right
            inp["left"] = not to_right
        "retreat", "block":
            inp["left"] = to_right
            inp["right"] = not to_right
        "jump":
            inp["up"] = true
            inp["right"] = to_right
            inp["left"] = not to_right
            ai_act = "idle"
        "punch":
            inp["punch"] = true
            ai_act = "idle"
        "kick":
            inp["kick"] = true
            ai_act = "idle"
    if (state == "punch" or state == "kick") and did_hit and randf() < 0.05:
        inp["punch" if randf() < 0.5 else "kick"] = true
    return inp

# ---------- LOGIC ----------
func _physics_process(delta: float) -> void:
    if Game.paused:
        return
    anim += delta
    scale = Vector2(facing * zoom, zoom)
    if position.y < FLOOR_Y or vel.y < 0.0:
        vel.y += GRAV * delta
    position += vel * delta
    if position.y >= FLOOR_Y and vel.y >= 0.0:
        position.y = FLOOR_Y
        vel.y = 0.0
        if state == "jump":
            state = "idle"
    position.x = clampf(position.x, 60.0, 1092.0)
    var grounded: bool = position.y >= FLOOR_Y
    queue_redraw()
    if locked or state == "ko" or state == "win":
        if grounded:
            vel.x = move_toward(vel.x, 0.0, 2200.0 * delta)
        return
    var inp := {"left": false, "right": false, "up": false, "punch": false, "kick": false}
    if dummy:
        if dummy_block:
            inp["left"] = facing == 1
            inp["right"] = facing == -1
    elif is_cpu:
        inp = _cpu_input(delta)
    else:
        inp = _human_input()
    want_p = inp["punch"] and not prev_p
    want_k = inp["kick"] and not prev_k
    prev_p = inp["punch"]
    prev_k = inp["kick"]
    combo_show = maxf(0.0, combo_show - delta)
    chain_t += delta
    if chain_t > 0.8 and state != "punch" and state != "kick" and not chain.is_empty():
        chain.clear()
    blocking = false
    match state:
        "hit":
            stun -= delta
            if grounded:
                vel.x = move_toward(vel.x, 0.0, 1400.0 * delta)
            if stun <= 0.0:
                state = "idle"
        "punch", "kick":
            _attack_tick(delta)
        _:
            if grounded:
                facing = 1 if opp.position.x > position.x else -1
                var dir: int = int(inp["right"]) - int(inp["left"])
                blocking = (facing == 1 and inp["left"]) or (facing == -1 and inp["right"])
                if want_p:
                    _start_attack("punch")
                elif want_k:
                    _start_attack("kick")
                elif inp["up"]:
                    vel = Vector2(dir * SPEED, JUMP_V)
                    state = "jump"
                else:
                    vel.x = 0.0 if blocking else dir * SPEED
                    state = "walk" if dir != 0 else "idle"

func _start_attack(a: String) -> void:
    state = a
    attack = a
    st_time = 0.0
    did_hit = false
    vel.x = 0.0

func _attack_tick(delta: float) -> void:
    st_time += delta
    var d: Dictionary = ATK[attack]
    var t_start: float = d["start"]
    var t_end: float = d["end"]
    if not did_hit and st_time >= t_start and st_time <= t_end:
        var x1: float = position.x + facing * 20.0
        var x2: float = position.x + facing * float(d["reach"])
        var hb := Rect2(minf(x1, x2), position.y - float(d["top"]), absf(x2 - x1), float(d["h"]))
        if hb.intersects(opp.hurtbox()):
            did_hit = true
            var blocked: bool = _register_hit(d)
            hit_landed.emit(Vector2(x2, position.y - float(d["top"]) + float(d["h"]) * 0.5), blocked)
    # HIT-CANCEL: once this attack connected, the next button chains straight into a new attack
    if did_hit and chain.size() < 4 and (want_p or want_k) and st_time >= t_start + 0.04:
        _start_attack("punch" if want_p else "kick")
        return
    if st_time >= float(d["total"]):
        if not did_hit:
            chain.clear()
        state = "idle"

func _register_hit(d: Dictionary) -> bool:
    chain.append(attack)
    chain_t = 0.0
    var bonus := 0
    var launch := false
    var cname := ""
    for c in Game.COMBOS:
        if c["seq"] == chain:
            bonus = int(c["bonus"])
            launch = bool(c["launch"])
            cname = str(c["name"])
            break
    var dealt: int = int(d["dmg"]) + bonus
    var blocked: bool = opp.take_hit(dealt, float(d["stun"]), facing, launch)
    if blocked:
        chain.clear()
    else:
        if chain.size() == 1:
            combo_dmg = 0
        combo_dmg += dealt
        combo_hits = chain.size()
        combo_name = cname
        combo_show = 1.6
    return blocked

func take_hit(dmg: int, stun_t: float, dir: int, launch: bool = false) -> bool:
    if state == "ko" or state == "win":
        return false
    var blk: bool = blocking and ((dir == 1 and facing == -1) or (dir == -1 and facing == 1))
    if blk:
        hp = maxi(hp - maxi(1, int(dmg * 0.2)), 0)
        vel.x = dir * 170.0
    else:
        hp = maxi(hp - dmg, 0)
        state = "hit"
        stun = stun_t
        vel.x = dir * 280.0
        if launch:
            vel = Vector2(dir * 240.0, -560.0)
            stun = 0.9
    if hp <= 0:
        state = "ko"
        vel = Vector2(dir * 320.0, -420.0)
    return blk

# ---------- DRAWING ----------
func _ext() -> float:
    var d: Dictionary = ATK[attack]
    var a: float = d["start"]
    var b: float = d["end"]
    var c: float = d["total"]
    if st_time < a:
        return st_time / a
    if st_time < b:
        return 1.0
    return clampf(1.0 - (st_time - b) / (c - b), 0.0, 1.0)

func _pose() -> Dictionary:
    var s: float = sin(anim * 7.0) * 3.0
    var hip := Vector2(-4, -86.0 + s * 0.5)
    var lean := 4.0
    var hx := 4.0
    var ff := Vector2(32, 0)
    var fb := Vector2(-30, 0)
    var hf := Vector2(40, -128.0 + s)
    var ef := Vector2(22, -106)
    var hb := Vector2(26, -138.0 + s)
    var eb := Vector2(6, -112)
    var ext := 0.0
    match state:
        "walk":
            var w: float = sin(anim * 13.0)
            var c: float = cos(anim * 13.0)
            ff = Vector2(10 + 32 * w, -12.0 * maxf(0.0, c))
            fb = Vector2(10 - 32 * w, -12.0 * maxf(0.0, -c))
            hip.y = -88.0 - absf(w) * 3.0
        "jump":
            ff = Vector2(34, -42)
            fb = Vector2(-18, -28)
            hip.y = -96
            hf = Vector2(46, -150)
            ef = Vector2(26, -126)
        "punch":
            ext = _ext()
            hf = Vector2(34 + ext * 80, -130)
            ef = Vector2(24 + ext * 34, -122)
            lean = 4 + ext * 10
            ff = Vector2(44, 0)
            fb = Vector2(-36, 0)
        "kick":
            ext = _ext()
            ff = Vector2(30 + ext * 98, -ext * 104)
            fb = Vector2(-26, 0)
            lean = 4 - ext * 12
            hx = 4 - ext * 8
            hip.x -= ext * 10
        "hit":
            hip.x = -12 + sin(anim * 60.0) * 2.0
            lean = -16
            hx = -10
            hf = Vector2(12, -96)
            ef = Vector2(2, -100)
            hb = Vector2(-12, -108)
            eb = Vector2(-14, -100)
        "ko":
            lean = 0
            hf = Vector2(30, -92)
            ef = Vector2(14, -100)
            hb = Vector2(20, -90)
            eb = Vector2(5, -100)
        "win":
            hip.y = -86.0 + sin(anim * 6.0) * 4.0
            hf = Vector2(40, -196)
            ef = Vector2(32, -164)
            hb = Vector2(26, -128)
    if blocking and (state == "idle" or state == "walk"):
        hf = Vector2(34, -148)
        ef = Vector2(20, -120)
        hb = Vector2(40, -120)
        eb = Vector2(22, -98)
    var kf: Vector2 = (hip + ff) * 0.5 + Vector2(14 - 22 * ext, -4 + 16 * ext)
    var kb: Vector2 = (hip + fb) * 0.5 + Vector2(8, -2)
    return {"hip": hip, "sh": hip + Vector2(lean, -48), "hx": hx, "ff": ff, "fb": fb, "kf": kf, "kb": kb,
        "hf": hf, "ef": ef, "hb": hb, "eb": eb}

func _limb(a: Vector2, b: Vector2, c: Vector2, w: float, col: Color) -> void:
    draw_line(a, b, col, w)
    draw_line(b, c, col, w)
    draw_circle(a, w * 0.5, col)
    draw_circle(b, w * 0.5, col)
    draw_circle(c, w * 0.5, col)

func _draw() -> void:
    draw_set_transform(Vector2(0, FLOOR_Y - position.y), 0.0, Vector2(1.0, 0.25))
    draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.35))
    if state == "ko":
        draw_set_transform(Vector2(0, -18), -PI / 2.0, Vector2.ONE)
    else:
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var p: Dictionary = _pose()
    var skin := Color(0.96, 0.76, 0.6)
    var pants := gi.darkened(0.12)
    var dark := Color(0.1, 0.1, 0.12)
    var sh: Vector2 = p["sh"]
    var hip: Vector2 = p["hip"]
    _limb(sh + Vector2(-6, 0), p["eb"], p["hb"], 15.0, skin)
    draw_circle(p["hb"], 10.0, band)
    _limb(hip, p["kb"], p["fb"], 22.0, pants)
    draw_rect(Rect2(Vector2(p["fb"]) + Vector2(-8, -7), Vector2(26, 11)), dark)
    draw_colored_polygon(PackedVector2Array([sh + Vector2(-18, -3), sh + Vector2(18, -3), hip + Vector2(15, 0), hip + Vector2(-15, 0)]), gi)
    draw_line(sh + Vector2(-4, -2), sh + Vector2(6, 26), skin, 4.0)
    draw_line(hip + Vector2(-16, -4), hip + Vector2(16, -4), dark, 9.0)
    _limb(hip, p["kf"], p["ff"], 24.0, pants)
    draw_rect(Rect2(Vector2(p["ff"]) + Vector2(-8, -7), Vector2(26, 11)), dark)
    var hd: Vector2 = sh + Vector2(p["hx"], -26)
    draw_circle(hd + Vector2(-3, -2), 21.0, dark)
    draw_circle(hd + Vector2(3, 3), 18.0, skin)
    draw_line(hd + Vector2(-18, -7), hd + Vector2(21, -7), band, 6.0)
    var wv: float = sin(anim * 10.0) * 6.0
    draw_line(hd + Vector2(-18, -7), hd + Vector2(-40, -2 + wv), band, 5.0)
    draw_line(hd + Vector2(-18, -7), hd + Vector2(-38, 8 - wv), band, 5.0)
    draw_circle(hd + Vector2(11, 1), 2.6, dark)
    draw_line(hd + Vector2(6, -3), hd + Vector2(17, -1), dark, 2.0)
    if state == "hit" or state == "ko":
        draw_circle(hd + Vector2(12, 12), 3.5, dark)
    else:
        draw_line(hd + Vector2(8, 12), hd + Vector2(16, 12), dark, 2.0)
    _limb(sh + Vector2(6, 0), p["ef"], p["hf"], 16.0, skin)
    draw_circle(p["hf"], 11.0, band)
