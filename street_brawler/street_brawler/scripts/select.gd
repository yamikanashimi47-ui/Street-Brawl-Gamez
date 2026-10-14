extends Node2D
## Character select, then stage select.

const FighterScript = preload("res://scripts/fighter.gd")
var step := 0   # 0 = fighter, 1 = stage
var t := 0.0
var preview

func _ready() -> void:
    preview = FighterScript.new()
    preview.locked = true
    preview.zoom = 2.3
    preview.position = Vector2(300, 560)
    add_child(preview)

func _process(delta: float) -> void:
    t += delta
    preview.visible = step == 0
    queue_redraw()

func _input(e: InputEvent) -> void:
    var ke := e as InputEventKey
    if ke == null or not ke.pressed or ke.echo:
        return
    var k: int = ke.keycode
    if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
        if step == 0:
            step = 1
        else:
            Game.goto("res://scenes/fight.tscn")
    elif k == KEY_ESCAPE:
        if step == 1:
            step = 0
        else:
            Game.goto("res://scenes/main_menu.tscn")

func _frame(r: Rect2, selected: bool) -> void:
    var c := Color(1.0, 0.85, 0.1) if (selected and int(t * 4.0) % 2 == 0) else Color(0.8, 0.12, 0.12)
    draw_rect(r.grow(6), c)
    draw_rect(r, Color(0.07, 0.07, 0.16))

func _draw() -> void:
    draw_rect(Rect2(0, 0, Game.W, Game.H), Color(0.05, 0.05, 0.13))
    for i in 6:
        var x: float = fmod(i * 260.0 + t * 40.0, 1500.0) - 200.0
        draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 90, 0), Vector2(x - 150, Game.H), Vector2(x - 240, Game.H)]), Color(0.12, 0.08, 0.25, 0.5))
    if step == 0:
        Game.ctext(self, "SELECT YOUR FIGHTER", 80, 54, Color(1.0, 0.85, 0.1))
        _frame(Rect2(60, 110, 480, 480), false)
        draw_circle(Vector2(300, 400), 190, Color(0.25, 0.2, 0.5, 0.5))
        for i in 4:
            var r := Rect2(640 + (i % 2) * 190, 170 + (i / 2) * 190, 160, 160)
            _frame(r, i == 0)
            if i == 0:
                var c := r.get_center()
                draw_circle(c + Vector2(0, 10), 52, Color(0.1, 0.1, 0.12))
                draw_circle(c + Vector2(6, 15), 44, Color(0.96, 0.76, 0.6))
                draw_line(c + Vector2(-46, -2), c + Vector2(52, -2), Color(0.9, 0.12, 0.15), 12)
                draw_circle(c + Vector2(24, 12), 5, Color(0.1, 0.1, 0.12))
            else:
                Game.label(self, "?", r.position + Vector2(0, 105), 90, Color(0.4, 0.4, 0.5), 160, true)
        Game.label(self, "KENJI", Vector2(640, 570), 60, Color.WHITE)
        Game.label(self, "SPEED 3/5   POWER 3/5", Vector2(640, 600), 22, Color(0.85, 0.85, 0.95))
    else:
        Game.ctext(self, "SELECT YOUR STAGE", 80, 54, Color(1.0, 0.85, 0.1))
        _frame(Rect2(346, 150, 461, 259), true)
        draw_set_transform(Vector2(346, 150), 0.0, Vector2(0.4, 0.4))
        Game.draw_stage(self, t)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        for x in [90.0, 932.0]:
            _frame(Rect2(x, 200, 130, 130), false)
            Game.label(self, "?", Vector2(x, 295), 80, Color(0.4, 0.4, 0.5), 130, true)
        Game.ctext(self, "DOJO SUNSET", 500, 58, Color.WHITE)
        Game.ctext(self, "Japan - Cherry Blossom Dojo", 540, 24, Color(0.85, 0.85, 0.95))
    Game.ctext(self, "ENTER: confirm      ESC: back", 630, 20, Color(0.8, 0.8, 0.9))
