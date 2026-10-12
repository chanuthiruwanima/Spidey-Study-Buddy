extends Control

@onready var closeBtn = $CloseBtn
@onready var modeToggleBtn = $BackgroundPanel/Icon

@onready var timerContainer = $Clock
@onready var timerLabelMins = $Clock/TimerMins
@onready var timerLabelSecs = $Clock/TimerSecs
@onready var resetBtn = $Clock/Restart
@onready var timerModeBtn = $Clock/ModeBtn
@onready var timerCtrl = $Clock/TimerCtrlBtn
@onready var timerCtrlText = $Clock/TimerCtrlBtn/TimerCtrlText

@onready var spidey = $SpideyCtrl/Spidey
@onready var spideyCtrl = $SpideyCtrl

@onready var consoleContainer = $Console
@onready var bobaBtn = $Console/FeedBtn
@onready var playBtn =$Console/SportBtn
@onready var sleepBtn = $Console/SleepBtn

@onready var dialogueBox = $DialogueBox
@onready var message = $DialogueBox/Message

@onready var clickSFX = $ClickSFX
@onready var chimeSFX = $ChimeSFX
@onready var petSFX = $PetSFX
@onready var squeakSFX = $SqueakSFX
@onready var blipSFX = $BlipSFX
@onready var snoreSFX = $SnoreSFX
@onready var popSFX = $PopSFX

const POS_CENTER = Vector2(145,120)
const POS_RIGHT = Vector2(220,150)

var mode: String = "timer"
var timer_mode: String = "focus"

const FOCUS_TIME = 25*60
const BREAK_TIME = 5*60
var time_remaining: int = 0
var timer_active: bool = false
var pomodoro: Timer

var spotify_check_timer: Timer
var is_spotify: bool = false

var hover_timer: Timer

var poke_count: int = 0
var poke_reset_timer: Timer
const MAX_POKES: int = 3
var is_hovering: bool = false
var previous_msg: String = ""
var idle_spidey_timer: Timer

func _ready():
	
	closeBtn.pressed.connect(_on_close_btn_pressed)
	pomodoro = Timer.new()
	pomodoro.wait_time = 1.0
	pomodoro.timeout.connect(_on_timer_timeout)
	add_child(pomodoro)
	
	spotify_check_timer = Timer.new()
	spotify_check_timer.wait_time = 3.0
	spotify_check_timer.timeout.connect(_check_spotify_status)
	spotify_check_timer.autostart = true
	add_child(spotify_check_timer)
	
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.5
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)
	
	poke_reset_timer = Timer.new()
	poke_reset_timer.wait_time = 2.0
	poke_reset_timer.one_shot = true
	poke_reset_timer.timeout.connect(_reset_poke_count)
	add_child(poke_reset_timer)
	
	idle_spidey_timer = Timer.new()
	idle_spidey_timer.one_shot = true
	idle_spidey_timer.timeout.connect(_on_idle_spidey_timeout)
	add_child(idle_spidey_timer)
	_reset_idle_spidey_timer()
	
	spideyCtrl.gui_input.connect(_on_spidey_tap)
	spideyCtrl.mouse_entered.connect(_on_spidey_hover_enter)
	spideyCtrl.mouse_exited.connect(_on_spidey_hover_exit)
	
	modeToggleBtn.pressed.connect(_on_mode_toggle_pressed)
	
	resetBtn.pressed.connect(_on_reset_button_pressed)
	timerCtrl.pressed.connect(_on_timer_ctrl_pressed)
	timerModeBtn.pressed.connect(_on_timer_mode_pressed)
	
	bobaBtn.pressed.connect(_on_feed_btn_pressed)
	playBtn.pressed.connect(_on_sport_btn_pressed)
	sleepBtn.pressed.connect(_on_sleep_btn_pressed)
	
	time_remaining = FOCUS_TIME
	
	_update_timer_label()
	if is_spotify:
		spidey.play("music")
	else:
		spidey.play("idle")
	
func _on_spidey_hover_enter():
	is_hovering = true
	if spidey.animation != "dizzy":
		hover_timer.start()


func _on_spidey_hover_exit():
	is_hovering = false
	hover_timer.stop()
	
	if spidey.animation != "dizzy":
		if is_spotify:
			spidey.play("music")
		else:
			spidey.play("idle")
func _on_hover_timer_timeout():
	if is_hovering and spidey.animation != "poke" and spidey.animation != "dizzy":
		spidey.play("pet")
		petSFX.play()

func _on_spidey_tap(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_poke_spidey()

func _poke_spidey():
	if spidey.animation == "dizzy":
		return
	hover_timer.stop()
	squeakSFX.play()
	poke_count +=1
	poke_reset_timer.start()
	
	if poke_count>=MAX_POKES:
		poke_count = 0
		_trigger_temp_animation("dizzy", 1)
	else:
		_trigger_temp_animation("poke", 1)

func _reset_poke_count():
	poke_count = 0

func _reset_idle_spidey_timer():
	
	if mode == "timer" and timer_mode=="focus":
		idle_spidey_timer.start(randf_range(45.0,120.0))
	else:
		idle_spidey_timer.start(randf_range(7.0,35.0))

func _on_idle_spidey_timeout():
	if spidey.animation == "idle":
		_play_random_behavoir()
	else:
		_reset_idle_spidey_timer()

func _play_random_behavoir():
	var behaviors = ["clumsy","talk","mask","music","sleepy","spark","venom"]
	if mode == "timer":
		behaviors.append_array(["climb_v","climb_h"])
	var current_behavior = behaviors.pick_random()
	
	if randf()<0.4:
		talk()
	match current_behavior:
		"clumsy":
			_trigger_temp_animation("clumsy",1)
		"music":
			_trigger_temp_animation("music",5)
		"spark" :
			_trigger_temp_animation("spark",1)
		"venom":
			_trigger_temp_animation("venom",1)
		"talk":
			_trigger_temp_animation("talk",4)
		"sleepy":
			_trigger_temp_animation("sleepy",1)
		"mask":
			_trigger_temp_animation("mask",1)
		"climb_v":
			await climb_v_behavior()
		"climb_h":
			await climb_h_behavior()
	_reset_idle_spidey_timer()
		
func _check_spotify_status() -> void:
	var output: Array = []
	var ps_command = "Get-Process Spotify -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -ne ''} | Select-Object -ExpandProperty MainWindowTitle"
	
	OS.execute("powershell", ["-Command", ps_command], output)
	
	var currently_playing = false
	if output.size()>0 and output[0].strip_edges() != "":
		var title = output[0].strip_edges()
		if not title.begins_with("Spotify"):
			currently_playing = true
	
	if currently_playing != is_spotify:
		is_spotify = currently_playing
		if is_spotify:
			spidey.play("music")
		else:
			spidey.play("idle")

func _on_mode_toggle_pressed():
	clickSFX.play()
	blipSFX.play()
	var tween = create_tween()
	if mode == "console":
		mode = "timer"
		timerContainer.visible = true
		consoleContainer.visible = false
		timerContainer.process_mode = Node.PROCESS_MODE_INHERIT
		consoleContainer.process_mode = Node.PROCESS_MODE_DISABLED
		tween.tween_property(spideyCtrl, "position", POS_RIGHT,0.35).set_trans(Tween.TRANS_SINE)
	elif mode == "timer":
		mode = "console"
		timerContainer.visible = false
		consoleContainer.visible = true
		timerContainer.process_mode = Node.PROCESS_MODE_DISABLED
		consoleContainer.process_mode = Node.PROCESS_MODE_INHERIT
		tween.tween_property(spideyCtrl, "position", POS_CENTER,0.35).set_trans(Tween.TRANS_SINE)
	
	_trigger_temp_animation("wow", 5)
			
func _on_timer_ctrl_pressed():
	clickSFX.play()
	timer_active = !timer_active
	if timer_active:
		pomodoro.start()
		timerCtrlText.text = "❚❚"
	else:
		pomodoro.stop()
		timerCtrlText.text = "▶"
		
func _on_reset_button_pressed():
	clickSFX.play()
	pomodoro.stop()
	timer_active = false
	timerCtrlText.text = "▶"
	if timer_mode == "focus":
		time_remaining = FOCUS_TIME
	else:
		time_remaining = BREAK_TIME
	_update_timer_label()
	_trigger_temp_animation("shock", 1)

func _on_timer_mode_pressed():
	clickSFX.play()
	blipSFX.play()
	pomodoro.stop()
	timer_active = false
	timerCtrlText.text = "▶"
	if timer_mode == "focus":
		timer_mode = "break"
		time_remaining = BREAK_TIME
	else:
		timer_mode = "focus"
		time_remaining = FOCUS_TIME
	_trigger_temp_animation("poke",1)
	_update_timer_label()

func _on_timer_timeout():
	if time_remaining>0:
		time_remaining -= 1
		_update_timer_label()
	else:
		pomodoro.stop()
		timer_active = false
		timerCtrlText.text = "▶"
		chimeSFX.play()
		_trigger_temp_animation("wow", 5)
		if timer_mode == "focus":
			timer_mode = "break"
			time_remaining = BREAK_TIME
		else:
			timer_mode = "focus"
			time_remaining = FOCUS_TIME
		_update_timer_label()

func _on_feed_btn_pressed():
	clickSFX.play()
	_trigger_temp_animation("boba", 6)
func _on_sport_btn_pressed():
	clickSFX.play()
	_trigger_temp_animation("play", 10)
func _on_sleep_btn_pressed():
	clickSFX.play()
	spidey.play("sleepy")
	await spidey.animation_finished
	_trigger_temp_animation("sleep",5)
	
func _update_timer_label():
	var minutes = time_remaining / 60
	var seconds = time_remaining % 60
	timerLabelMins.text = "%02d" % minutes
	timerLabelSecs.text = "%02d" % seconds
	
func _trigger_temp_animation(anim_name: String, loops: int):
	spidey.play(anim_name)
	for i in range(loops):
		await spidey.animation_looped
	if is_spotify:
		spidey.play("music")
	else:
		spidey.play("idle")

func talk():

	var timer_messages: Array[String]= [
		"LOCK IN",
		"KEEP GOING",
		"REMEMBER TO HYDRATE",
		"I TRIED ASKING DR. STRANGE FOR HELP STUDYING ONCE. BAD IDEA",
		"FOCUS",
		"IS IT TOO LATE TO DROP THIS CLASS? ASKING FOR A FRIEND.",
		"EXAMS...THE GREATEST VILLAIN",
		"IF I CAN UNDERSTAND QUANTUM PHYSICS, WE CAN GET THIS",
		"WE'RE ALMOST DONE (OR ATLEAST THAT'S WHAT I KEEP TELLING MYSELF)",
		"HEY, DON'T LOOK AT ME. LOOK BACK AT YOUR WORK",
		"YOU WRITE A PARAGRAPH...I'LL...STAY PIXELATED. TEAMWORK!",
		"WHATEVER YOU'RE DOING OVER THERE...I BELIEVE IN YOU",
		"YOU'VE GOT THIS!",
		"ONE MORE PRACTICE QUESTION?",
		"YOUR FUTURE SELF IS GONNA THANK YOU FOR STAYING FOCUSED RIGHT NOW",
		"SMALL PROGRESS IS STILL PROGRESS",
		"PEARSON EXAMINERS ARE DEFINITELY WORKING WITH GREEN GOBLIN",
		"ARE WE AIMING FOR AN A OR JUST TRYING TO STAY AWAKE? GENUINE QUESTION",
		"IF YOU THINK IT'S AN EASY TOPIC, READ IT AGAIN",
		"YOUR BRAIN IS WORKING EVEN WHEN IT FEELS LIKE IT'S NOT",
		"TAKE A DEEP BREATH, THEN TRY AGAIN",
		"NOBODY WANTS TO DO THIS, BUT WE HAVE TO",
		"TAKE YOUR TIME, I'M NOT GOING ANYWHERE",
		"PRO TIP: COLOUR CODING NOTES WORKS UNTIL YOU RUN OUT OF HIGHLIGHTERS. LEARNED THAT THE HARD WAY.",
		"MY REVISION METHOD IS STARING AT THE PAGE UNTIL IT ENTERS MY BRAIN",
		"IF ANYONE ASKS, WE'RE BOTH WORKING VERY HARD RIGHT NOW",
		"DON'T MIND ME. JUST PRETENDING I UNDERSTAND...WHATEVER THAT IS.",
		"STILL WAITING FOR A RADIOACTIVE SPIDER TO GIVE ME BETTER STUDY HABITS.",
	]
	var console_messages: Array[String]= [
		"HEY, WHAT ARE WE WATCHING NEXT?",
		"IF I DO A BACKFLIP, WILL YOU GIVE ME A SNACK?",
		"10/10 DESKTOP SETUP. VERY COZY",
		"I WENT FROM FIGHTING THANOS TO LIVING IN A DESKTOP WINDOW. WHAT A PROMOTION.",
		"I TOLD TONY I NEEDED A SUIT UPGRADE AND HE SENT ME A USER MANUAL FOR A TOASTER",
		"JUST SITTING HERE. WATCHING YOU CLICK THINGS",
		"CAPTAIN AMERICA WOULD PROBABLY TELL YOU TO STRETCH YOUR LEGS",
		"DO YOU EVER JUST STARE AT YOUR SCREEN...AND COMPLETELY FORGET WHAT YOU WERE SUPPSOED TO DO?",
		"HOLD STILL, LET ME GET A COOL POLAROID OF US FOR THE DESKTOP",
		"I TRIED TO READ PERCY JACKSON ONCE AND THOUGHT MY SPIDER-SENSE WAS A DEMIGOD THING",
		"I TRIED TO USE MY WEBS AS A BOOKMARK ONCE. IT... DID NOT END WELL FOR THE PAPER",
		"I TRIED TO DO A SPIN-JITZU MOVE IN MY ROOM AND TRIPPED OVER MY SNEAKERS",
		"JUMP UP, KICK BACK, WHIP AROUND AND SPIN...SO JEALOUS THAT ISN'T MY THEME SONG",
		"UNCLE IROH WOULD PROBABLY TELL US BOTH TO STOP WORKING AND DRINK SOME TEA",
		"PLEASE DON'T MINIMIZE ME, IT'S DARK IN THAT TASKBAR",
		"IF YOU'RE GETTING REAL ICED COFFEE, CAN YOU PRESS A BUTTON TO GIVE ME SOME?",
		"HELP. I WEBBED MY FEET TO THE BOTTOM OF THE WINDOW",
		"YOUR CURSOR JUST FLEW PAST ME LIKE A GIANT GLIDER. SPIDEY-SENSE IS BUZZING!",
		"CAN WE MOVE TO A SUNNIER SPOT ON THE SCREEN?",
		"I FELL ASLEEP FOR A SECOND. DID I MISS ANYTHING COOL?",
		"I TRIED TO PRACTICE CABBAGE-PROTECTION DRILLS IN CASE I CRASH INTO A CART",
		"I TOLD TONY WE NEEDED A FLYING BISON FOR THE TEAM. HE JUST STARED AT ME",
		"CAN YOU DRAG ME CLOSER TO THE MIDDLE? I FEEL LIKE I'M IN TIMEOUT",
		"I ACCIDENTALLY WEBBED YOUR WEBCAM...A NEW FILTER?",
		"I SWEAR MY PHYSICS TEXTBOOK IS WRITTEN IN ANCIENT GREEK AT THIS POINT"
	]
	var msg: String
	
	if mode == "timer":
		msg = timer_messages.pick_random()
		while msg == previous_msg:
			msg = timer_messages.pick_random()
	else:
		msg = console_messages.pick_random()
		while msg == previous_msg:
			msg = console_messages.pick_random()
	previous_msg = msg
	message.text = msg
	message.reset_size()
	
	dialogueBox.size = Vector2(clamp(message.size.x + 16, 100, 140),message.size.y + 12)
	
	popSFX.play()
	dialogueBox.visible = true
	await get_tree().create_timer(5.0).timeout
	dialogueBox.visible = false
	message.text = ""

func climb_v_behavior():
	var start_pos = spideyCtrl.position
	spidey.play("climb_v")
	var climb_tween = create_tween().set_parallel(false)
	climb_tween.tween_property(spideyCtrl, "position", Vector2(start_pos.x,start_pos.y-14), 1.4).set_trans(Tween.TRANS_SINE)
	climb_tween.tween_property(spideyCtrl, "position", Vector2(start_pos.x, start_pos.y), 1.2).set_trans(Tween.TRANS_SINE)
	await climb_tween.finished
	
		
	if is_spotify:
		spidey.play("music")
	else:
		spidey.play("idle")
		
func climb_h_behavior():
	var start_pos = spideyCtrl.position
	spidey.play("climb_h")
	var climb_tween = create_tween().set_parallel(false)
	climb_tween.tween_property(spideyCtrl, "position", Vector2(start_pos.x-12,start_pos.y), 1.2).set_trans(Tween.TRANS_SINE)
	climb_tween.tween_property(spideyCtrl, "position", Vector2(start_pos.x, start_pos.y),1.0).set_trans(Tween.TRANS_SINE)
	await climb_tween.finished
	
	if is_spotify:
		spidey.play("music")
	else:
		spidey.play("idle")
		
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			DisplayServer.window_start_drag()
func _on_close_btn_pressed():
	clickSFX.play()
	await clickSFX.finished
	get_tree().quit()
