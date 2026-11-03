class_name OSCInputReceiver
extends Node

@export var port: int = 9000
@export var surface: Node # MappedSurface or GridMappedSurface

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

	# OSC Format: starts with '/' (0x2F)
	if pkt[0] == 0x2F:
		_parse_osc_packet(pkt)
		return

	# Multi-Touch Protocol Extension (10 bytes):
	# [1 byte cmd (1=down, 2=up, 3=move), 1 byte touch_id (0..255), 4 bytes float x, 4 bytes float y]
	if pkt.size() >= 10:
		var cmd: int = pkt.decode_u8(0)
		var touch_id: int = pkt.decode_u8(1)
		var x: float = _decode_float_big_endian(pkt, 2)
		var y: float = _decode_float_big_endian(pkt, 6)
		_dispatch_touch_point(touch_id, cmd, Vector2(x, y))
		return

	# Legacy Single-Touch Protocol (9 bytes):
	# [1 byte cmd, 4 bytes float x, 4 bytes float y]
	if pkt.size() >= 9:
		var cmd: int = pkt.decode_u8(0)
		var x: float = _decode_float_big_endian(pkt, 1)
		var y: float = _decode_float_big_endian(pkt, 5)
		_dispatch_touch_point(0, cmd, Vector2(x, y))

func _dispatch_touch_point(touch_id: int, cmd: int, pos: Vector2) -> void:
	if not surface:
		return
	var is_pressed := (cmd == 1 or cmd == 3)
	if surface.has_method("inject_touch_point"):
		surface.inject_touch_point(touch_id, pos, is_pressed)
	elif surface.has_method("inject_normalized_point"):
		surface.inject_normalized_point(pos, is_pressed)

static func _decode_float_big_endian(pkt: PackedByteArray, offset: int) -> float:
	var slice = pkt.slice(offset, offset + 4)
	slice.reverse()
	return slice.decode_float(0)

func _parse_osc_packet(pkt: PackedByteArray) -> void:
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

	var data_offset: int = (type_tag_end + 4) & ~3
	var touch_id: int = 0
	var cmd: int = 1
	var x: float = 0.0
	var y: float = 0.0
	var float_count: int = 0

	for idx in range(1, type_tags.length()):
		var t = type_tags[idx]
		if t == "i":
			var val: int = pkt.decode_s32(data_offset)
			data_offset += 4
			touch_id = val
		elif t == "f":
			var val: float = pkt.decode_float(data_offset)
			data_offset += 4
			if float_count == 0:
				x = val
			elif float_count == 1:
				y = val
			float_count += 1
		elif t == "T":
			cmd = 1
		elif t == "F":
			cmd = 2

	if float_count >= 2:
		_dispatch_touch_point(touch_id, cmd, Vector2(x, y))
