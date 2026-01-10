extends RefCounted
class_name Device

# Identity (owned by the device itself)
var hostname: String = "new-device"
var mac: String
var hack_chance: float = 0.35
var hwtype: String = "ether"
# hw type can be: { "ether", "wifi", "cell", "bt" } that's it #

# --- NETWORK PASSWORD: SETS PASSWORD FOR HACK'ING MINIGAME --- #
var network_password: String = ""

# ARP BEHAVIOR #
enum NeighborState { INCOMPLETE, REACHABLE, STALE, DELAY, PROBE, FAILED, PERMANENT }
var neighbor_state_override: int = -1 # -1 = no override; otherwise NeighborState.*
var arp_last_seen_ms: int = -1        # When we last confirmed the mapping
var arp_ever_seen: bool = false       # did we ever resolve this device?
var is_router: bool = false           # mark routers
var arp_state: String = "INCOMPLETE"
var iface: String = ""
var netmask: String = ""
var arp_flags: String = ""

# Experience system
var hack_xp_first: int = 25
var hack_xp_repeat: int = 3
var was_hacked: bool = false

# Network state (assigned by Network)
var ip_address: String = ""
var network: Network = null
var online: bool = true

# Filesystem on devices
var fs: FileSystem

# -------------------------------------------------
# NEW: Banking / Ledger support (optional per device)
# -------------------------------------------------
var supports_banking: bool = false

# Simple auth model (username -> password)
var bank_users: Dictionary = {}          # e.g. { "ops":"Winter2026!" }
var bank_sessions: Dictionary = {}       # session_id -> username

# Where the protected ledger lives
var bank_ledger_path: String = "/srv/bank/core/db/ledger.dat"


func _init() -> void:
	# Ensure MAC exists
	if mac == "" or mac == null:
		mac = _generate_mac()

	# Ensure filesystem exists (IMPORTANT: always initialize)
	if fs == null:
		fs = FileSystem.new()
		fs.mkdir("/home")

# Identity accessors
func get_ip() -> String:
	return ip_address

func get_mac() -> String:
	return mac

func get_hostname() -> String:
	return hostname

# Network attachment
func attach_to_network(net: Network) -> void:
	network = net
	net.register_device(self)

func detach_from_network() -> void:
	if network:
		network.unregister_device(self)
	network = null
	ip_address = ""

# -------------------------------------------------
# Banking helpers
# -------------------------------------------------

# Call this ONCE when building the bank server device.
# accounts format:
# {
#   "041702993144": {"balance": 1824.55, "owner":"C-10021"},
#   "041702993402": {"balance": 993.12, "owner":"C-10088"}
# }
func bank_seed_ledger(accounts: Dictionary) -> void:
	supports_banking = true
	if fs == null:
		fs = FileSystem.new()

	# Ensure dirs exist
	fs.mkdir("/srv")
	fs.mkdir("/srv/bank")
	fs.mkdir("/srv/bank/core")
	fs.mkdir("/srv/bank/core/db")

	# Write protected data file so players can't "echo" edit it
	fs.write_data_file(
		bank_ledger_path,
		{
			"accounts": accounts,
			"transfers": []   # audit trail
		},
		true,
		{"schema": "brokebank-ledger-v1"}
	)

# Very simple login: returns session_id or "" if failed
func bank_login(user: String, pass: String) -> String:
	if not supports_banking:
		return ""
	if not bank_users.has(user):
		return ""
	if String(bank_users[user]) != pass:
		return ""

	var sid := "sess_%s" % str(randi())
	bank_sessions[sid] = user
	return sid

func bank_is_session_valid(session_id: String) -> bool:
	return supports_banking and bank_sessions.has(session_id)

# Transfer between internal accounts (ledger update). Does NOT automatically give Player currency.
func bank_transfer(session_id: String, from_acct: String, to_acct: String, amount: float) -> Dictionary:
	# returns: {"ok":bool,"msg":String,"moved":float}
	if not supports_banking:
		return {"ok": false, "msg": "banking not supported", "moved": 0.0}

	if not bank_is_session_valid(session_id):
		return {"ok": false, "msg": "unauthorized: invalid session", "moved": 0.0}

	if amount <= 0.0:
		return {"ok": false, "msg": "invalid amount", "moved": 0.0}

	if fs == null:
		return {"ok": false, "msg": "filesystem missing", "moved": 0.0}

	var ledger := fs.read_data_file(bank_ledger_path)
	if ledger.is_empty():
		return {"ok": false, "msg": "ledger missing", "moved": 0.0}

	var accounts: Dictionary = ledger.get("accounts", {})
	if not accounts.has(from_acct) or not accounts.has(to_acct):
		return {"ok": false, "msg": "account not found", "moved": 0.0}

	var from_data: Dictionary = accounts[from_acct]
	var to_data: Dictionary = accounts[to_acct]

	var bal := float(from_data.get("balance", 0.0))
	if bal < amount:
		return {"ok": false, "msg": "insufficient funds", "moved": 0.0}

	# debit/credit
	from_data["balance"] = bal - amount
	to_data["balance"] = float(to_data.get("balance", 0.0)) + amount
	accounts[from_acct] = from_data
	accounts[to_acct] = to_data
	ledger["accounts"] = accounts

	# audit trail
	var transfers: Array = ledger.get("transfers", [])
	transfers.append({
		"ts": Time.get_unix_time_from_system(),
		"user": bank_sessions[session_id],
		"from": from_acct,
		"to": to_acct,
		"amount": amount
	})
	ledger["transfers"] = transfers

	# Because the ledger is protected, we overwrite it through the Device API.
	fs.write_data_file(bank_ledger_path, ledger, true, {"schema": "brokebank-ledger-v1"})

	return {"ok": true, "msg": "transfer complete", "moved": amount}

# -------------------------------------------------
# Internal helpers
# -------------------------------------------------

func _generate_mac() -> String:
	var bytes: Array[int] = []
	for i in range(6):
		bytes.append(randi_range(0, 255))

	# Locally administered + unicast (more realistic-ish)
	bytes[0] = (bytes[0] & 0xFE) | 0x02

	return "%02X:%02X:%02X:%02X:%02X:%02X" % bytes

# --- ARP HELPERS --- #

func get_arp_state(now_ms: int) -> int:
	# Hard override (rare, but useful)
	if neighbor_state_override != -1:
		return neighbor_state_override

	if is_router:
		return NeighborState.PERMANENT

	# Never resolved yet
	if not arp_ever_seen:
		return NeighborState.INCOMPLETE

	# Was resolved before, but currently offline
	if not online:
		return NeighborState.FAILED

	# Resolved and online: decide freshness
	var age := now_ms - arp_last_seen_ms
	if age <= 30_000:
		return NeighborState.REACHABLE

	return NeighborState.STALE
