extends Node
class_name NetworkHeartbeat

const HEARTBEAT_SEC: float = 120.0
const CLEAR_STRIKES_ON_RESTORE := true

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = HEARTBEAT_SEC
	add_child(_timer)
	_timer.timeout.connect(_on_heartbeat)
	_timer.start()

	# Publish initial telemetry so netstat has interval + next immediately.
	_publish_hb_meta_initial()

	# IMPORTANT:
	# Do NOT call _on_heartbeat immediately if you want the first "last=--"
	# for the first interval (your preference).
	# So we do NOT call_deferred("_on_heartbeat").


func _publish_hb_meta_initial() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return

	var now_ms: int = Time.get_ticks_msec()
	var interval_ms: int = int(round(HEARTBEAT_SEC * 1000.0))

	root.set_meta("net_hb_interval_ms", interval_ms)
	root.set_meta("net_hb_last_ms", 0) # last stays -- until first timer fires
	root.set_meta("net_hb_next_ms", now_ms + interval_ms)


func _publish_hb_meta_tick(now_ms: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return

	var interval_ms: int = int(round(HEARTBEAT_SEC * 1000.0))
	root.set_meta("net_hb_interval_ms", interval_ms)
	root.set_meta("net_hb_last_ms", now_ms)
	root.set_meta("net_hb_next_ms", now_ms + interval_ms)


func _on_heartbeat() -> void:
	var me: Device = World.current_device
	if me == null:
		return

	var net: Network = me.network
	if net == null:
		return

	var now_ms: int = Time.get_ticks_msec()

	# Publish timing info for netstat
	_publish_hb_meta_tick(now_ms)

	for d in net.devices:
		if d == null:
			continue

		# already online -> nothing to do
		if _get_bool(d, "online", true):
			continue

		# still locked out (matches CmdSSH: offline_until_ms)
		var offline_until := int(_get_any(d, "offline_until_ms", 0))
		if offline_until > 0 and now_ms < offline_until:
			continue

		_restore_device_to_network(net, d)


func _restore_device_to_network(net: Network, d: Device) -> void:
	# Bring online
	_set_any(d, "online", true)
	_set_any(d, "offline_until_ms", 0)

	if CLEAR_STRIKES_ON_RESTORE:
		_set_any(d, "ssh_fail_count", 0)

	# Re-attach via your existing network logic if available
	if net.has_method("_attach_to_network"):
		net._attach_to_network(d)
	elif d.has_method("_attach_to_network"):
		d._attach_to_network(net)
	else:
		pass


# ------------------------------------------------------------
# Safe property/meta helpers
# ------------------------------------------------------------
func _get_bool(o: Object, field: String, fallback: bool) -> bool:
	var v = _get_any(o, field, null)
	if v == null:
		return fallback
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	var s := str(v).to_lower()
	if s == "true": return true
	if s == "false": return false
	return fallback


func _get_any(o: Object, field: String, fallback):
	if o == null:
		return fallback
	if field in o:
		var v = o.get(field)
		return fallback if v == null else v
	if o.has_meta(field):
		var mv = o.get_meta(field)
		return fallback if mv == null else mv
	return fallback


func _set_any(o: Object, field: String, value) -> void:
	if o == null:
		return
	if field in o:
		o.set(field, value)
	else:
		o.set_meta(field, value)
