extends Node2D
## Title screen -> main menu -> how-to-play.

const ITEMS := ["ARCADE  -  1P vs CPU", "VERSUS  -  2 PLAYERS", "PRACTICE  -  TRAINING", "HOW TO PLAY", "QUIT"]
var phase := "title"   # title / menu / help
var sel := 0
var t := 0.0

func _process(delta: float) -> void:
    t += delta
    queue_redraw()

func _input(e: InputEvent) -> void:
    var ke := e as InputEventKey
    if ke == null or not ke.pressed or ke.echo:
        return
    var k: int = ke.keycode
    var confirm: bool = k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
    if phase == "title":
        if confirm:
            phase = "menu"
    elif phase == "help":
        phase = "menu"
    else:
        if k == KEY_UP or k == KEY_W:
            sel = (sel + ITEMS.size() - 1) % ITEMS.size()
        elif k == KEY_DOWN or k == KEY_S:
            sel = (sel + 1) % ITEMS.size()
        elif k == KEY_ESCAPE:
            phase = "title"
        elif confirm:
            _choose()

func _choose() -> void:
    match sel:
        0:
            Game.mode = "cpu"
            Game.goto("res://scenes/select.tscn")
        1:
            Game.mode = "versus"
            Game.goto("res://scenes/select.tscn")
        2:
            Game.mode = "practice"
            Game.goto("res://scenes/select.tscn")
        3:
            phase = "help"
        4:
            get_tree().quit()

func _draw() -> void:
    Game.draw_stage(self, t)
    draw_rect(Rect2(0, 0, Game.W, Game.H), Color(0, 0, 0, 0.35))
    Game.ctext(self, "STREET", 190, 130, Color(1.0, 0.85, 0.1))
    Game.ctext(self, "BRAWLER", 310, 130, Color(0.95, 0.15, 0.15))
    if phase == "title":
        if int(t * 2.0) % 2 == 0:
            Game.ctext(self, "PRESS ENTER", 480, 44, Color.WHITE)
        Game.ctext(self, "Made with Godot", 610, 20, Color(0.9, 0.9, 0.9))
    elif phase == "menu":
        for i in ITEMS.size():
            var y: float = 392.0 + i * 46.0
            if i == sel:
                var pulse: float = 0.75 + 0.25 * sin(t * 8.0)
                Game.ctext(self, "> " + ITEMS[i] + " <", y, 36, Color(1.0, 0.85 * pulse, 0.1))
            else:
                Game.ctext(self, ITEMS[i], y, 32, Color(0.92, 0.92, 0.92))
        Game.ctext(self, "W/S or Up/Down: move    ENTER: select", 636, 18, Color(0.9, 0.9, 0.9))
    else:
        draw_rect(Rect2(140, 380, 872, 240), Color(0, 0, 0, 0.75))
        Game.ctext(self, "PLAYER 1:  A / D move    W jump    F punch    G kick", 425, 26, Color.WHITE)
        Game.ctext(self, "PLAYER 2:  Left / Right move    Up jump    K punch    L kick", 470, 26, Color.WHITE)
        Game.ctext(self, "Hold the direction AWAY from your enemy to BLOCK", 520, 24, Color(1, 0.85, 0.2))
        Game.ctext(self, "Win 2 rounds.  Chain hits for combos.  ESC / P = pause + combo list.", 565, 22, Color(0.9, 0.9, 0.9))
        Game.ctext(self, "press any key", 605, 18, Color(0.8, 0.8, 0.8))
