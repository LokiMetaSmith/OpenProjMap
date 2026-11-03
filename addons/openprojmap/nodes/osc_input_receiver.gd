class_name OSCInputReceiver
extends Node

@export var port: int = 9000
@export var surface: MappedSurface

var server: UDPServer

func _ready() -> void:
	server = UDPServer.new()
	var err = server.listen(port)
	if err != OK:
		push_error("Failed to bind UDP server on port %d" % port)

func _process(_delta: float) -> void:
	if not server:
		return
	server.poll()
	if server.is_connection_available():
		var peer: PacketPeerUDP = server.take_connection()
		while peer.get_available_packet_count() > 0:
			var pkt: PackedByteArray = peer.get_packet()
			_parse_packet(pkt)

func _parse_packet(pkt: PackedByteArray) -> void:
	if pkt.size() == 0:
		return

	# Check for OSC format (starts with '/' string e.g. /touch or /cursor)
	if pkt[0] == 0x2F: # ASCII '/'
		_parse_osc_packet(pkt)
		return

	# Compact Binary Protocol:
	# Protocol: 1-byte command (0x01 = touch_down, 0x02 = touch_up, 0x03 = move)
	# Followed by 2x 32-bit big-endian floats (x, y normalized 0.0 .. 1.0)
	if pkt.size() < 9:
		return

	var cmd: int = pkt.decode_u8(0)
	var x: float = _decode_float_big_endian(pkt, 1)
	var y: float = _decode_float_big_endian(pkt, 5)
	var pos := Vector2(x, y)

	if surface:
		var is_pressed := (cmd == 1 or cmd == 3)
		surface.inject_normalized_point(pos, is_pressed)

static func _decode_float_big_endian(pkt: PackedByteArray, offset: int) -> float:
	var slice = pkt.slice(offset, offset + 4)
	slice.reverse()
	return slice.decode_float(0)

func _parse_osc_packet(pkt: PackedByteArray) -> void:
	# Minimal robust OSC parser for addresses like /touch or /cursor with format ",iff" or ",ff"
	var address_end: int = -1
	for i in range(pkt.size()):
		if pkt[i] == 0:
			address_end = i
			break
	if address_end <= 0:
		return

	var type_tag_start: int = -1
	for i in range(address_end, pkt.size()):
		if pkt[i] == 0x2C: # ','
			type_tag_start = i
			break

	if type_tag_start == -1:
		return

	var type_tag_end: int = type_tag_start + 1
	while type_tag_end < pkt.size() and pkt[type_tag_end] != 0:
		type_tag_end += 1

	var type_tags: String = pkt.slice(type_tag_start, type_tag_end).get_string_from_ascii()

	# Align data offset to 4 bytes boundary
	var data_offset: int = (type_tag_end + 4) & ~3
	var is_pressed: bool = true
	var x: float = 0.0
	var y: float = 0.0

	var float_count: int = 0
	for idx in range(1, type_tags.length()):
		var t = type_tags[idx]
		if t == "i":
			var val: int = pkt.decode_s32(data_offset)
			data_offset += 4
			is_pressed = (val != 0)
		elif t == "f":
			var val: float = pkt.decode_float(data_offset)
			data_offset += 4
			if float_count == 0:
				x = val
			elif float_count == 1:
				y = val
			float_count += 1
		elif t == "T":
			is_pressed = true
		elif t == "F":
			is_pressed = false

	if float_count >= 2 and surface:
		surface.inject_normalized_point(Vector2(x, y), is_pressed)
