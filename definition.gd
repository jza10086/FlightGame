## Lightweight catalog data. Do not load gameplay scenes or scripts here.
extends RefCounted

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": {"flight_pitch_up": "抬头", "flight_pitch_down": "低头", "flight_bank_left": "向左滚转", "flight_bank_right": "向右滚转", "flight_yaw_left": "左方向舵", "flight_yaw_right": "右方向舵", "flight_throttle_up": "增加油门", "flight_throttle_down": "减少油门", "flight_brake": "刹车", "flight_reset": "重新起飞", "flight_landing": "着陆练习", "flight_mouse": "鼠标操纵开关", "flight_invert": "反转鼠标", "flight_less": "降低灵敏度", "flight_more": "提高灵敏度", "flight_help": "操作说明", "flight_camera": "切换相机", "flight_mute": "声音开关", "flight_capture": "捕获鼠标"}}
