class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D

@export var max_raycast_distance: float = 100.0;
@export var update_frequency_seconds: float = 0.25 + randf()*0.2; # Don't want to do them all at the same time
@export var max_reverb_wetness: float = 0.5;
@export var wall_lowpass_cutoff_amount: int = 1000;
var horizontalCheck:float = 1.0;
var verticalCheck:float = 0.8;

var _raycast_array: Array = []
var _distance_array: Array = [{},{},{},{},{}, {},{},{},{},{}]
var _last_update_time : float = 0.0
var _update_distances : bool = true
var _current_raycast_index : int = 0

var _audio_bus_idx = null
var _audio_bus_name = ""

var _reverb_effect : AudioEffectReverb
var _lowpass_filter : AudioEffectLowPassFilter
var _eq_filter : AudioEffectEQ

var _target_lowpass_cutoff : float = 20000
var _target_reverb_room_size : float = 0.0
var _target_reverb_wetness : float = 0.0
var _target_volume_db : float = 0.0
var _target_reverb_dampening: float = 0.5
var _target_reverb_reflection_time: float = 0.0

var _target_32hz_reduction:float = 0.0
var _target_100hz_reduction:float = 0.0
var _target_320hz_reduction:float = 0.0
var _target_1000hz_reduction:float = 0.0
var _target_3200hz_reduction:float = 0.0
var _target_10000hz_reduction:float = 0.0

func _ready():
	# Make new audio bus
	_audio_bus_idx = AudioServer.bus_count
	_audio_bus_name = "SpatialBus#"+str(_audio_bus_idx)
	AudioServer.add_bus(_audio_bus_idx)
	AudioServer.set_bus_name(_audio_bus_idx, _audio_bus_name);
	self.bus = _audio_bus_name
	
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectReverb.new(), 0);
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectLowPassFilter.new(), 1);
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectEQ.new(), 2);
	_reverb_effect = AudioServer.get_bus_effect(_audio_bus_idx, 0);
	_lowpass_filter = AudioServer.get_bus_effect(_audio_bus_idx, 1);
	_eq_filter = AudioServer.get_bus_effect(_audio_bus_idx, 2);
	
	_target_volume_db = volume_db;
	volume_db = -60.0;
	_raycast_array.append_array([
		$RayCastBackward, $RayCastBackwardLeft, $RayCastBackwardRight,
		$RayCastFoward, $RayCastFowardLeft, $RayCastFowardRight,
		$RayCastLeft, $RayCastRight,
		$RayCastUp,
		$RayCastPlayer
		]);

	for raycast:RayCast3D in _raycast_array:
		raycast.target_position *= max_raycast_distance
	if self.stream:
		$Annotation/Label3D.text = self.stream.resource_path.get_file().get_basename()
	AudioServer.playback_speed_scale = 1.0

func randomise_raycast_direction(raycast: RayCast3D):
	raycast.target_position = Vector3((randf()*2.0)-1.0, (randf()*2.0)-1.0, (randf()*2.0)-1.0)*max_raycast_distance

func _on_update_raycast_distance(raycast: RayCast3D, raycast_index: int):
	randomise_raycast_direction(raycast)
	raycast.force_raycast_update()
	var collider = raycast.get_collider()
	_distance_array[raycast_index]["distance"] = -1
	_distance_array[raycast_index]["material"] = null
	if collider != null:
		_distance_array[raycast_index]["distance"] = self.global_position.distance_to(raycast.get_collision_point());
		
		if (collider is StaticBody3D and
			collider.physics_material_override and
			collider.physics_material_override is ExpandedPhysicsMaterial):
			_distance_array[raycast_index]["material"] = collider.physics_material_override
	raycast.enabled = false;

func _on_update_spatial_audio(player: Node3D):
	_on_update_reverb(player);
	_on_update_lowpass_filter(player);

func _on_update_reverb(player: Node3D):
	if !_reverb_effect:
		return
	var room_size = 0.0
	var wetness = 1.0
	var dampening = 0.5
	var reflectionTime = 0.0
	for dist in _distance_array:
		if dist["material"]:
			dampening += dist["material"].dampening
		else:
			dampening += 0.5
		# Getting how long for reflections.
		if dist["distance"] >= 0:
			reflectionTime += (dist["distance"] * 343 * 0.001) # Speed of sound
		if dist["distance"] >= 0:
			# find average room size based on valid distances
			room_size += (dist["distance"] / max_raycast_distance) / (float(_distance_array.size()))
			room_size = min(room_size, 1.0);
		else:
			wetness -= 1.0/float(_distance_array.size());
			wetness = max(wetness, 0.0);

	_target_reverb_wetness = wetness;
	_target_reverb_room_size = room_size;
	_target_reverb_dampening = dampening/_distance_array.size()
	_target_reverb_reflection_time = reflectionTime/_distance_array.size()

func _on_update_lowpass_filter(player: Node3D):
	if !_lowpass_filter:
		return
	var bandReductions = [0,0,0,0,0,0]
	var lowPassArray:Array = []
	for i in [
		Vector3(horizontalCheck,0,0), Vector3(-horizontalCheck,0,0),
		Vector3(0,0,horizontalCheck), Vector3(0,0,-horizontalCheck),
		Vector3(0,verticalCheck, horizontalCheck), Vector3(0,verticalCheck, -horizontalCheck),
		Vector3(horizontalCheck,verticalCheck, 0), Vector3(-horizontalCheck,verticalCheck, 0),
		Vector3(0,0,0)
	]:
		$RayCastPlayer.target_position = (player.global_position - self.global_position + i).normalized() * max_raycast_distance
		$RayCastPlayer.force_raycast_update()
		var collider = $RayCastPlayer.get_collider();
		
		var _lowpass_cutoff = 20000;

		if collider:
			var ray_distance = self.global_position.distance_to($RayCastPlayer.get_collision_point());
			var distance_to_player = self.global_position.distance_to(player.global_position)
			var wall_to_player_ratio = ray_distance / max(distance_to_player, 0.001)
			if ray_distance < distance_to_player:
				_lowpass_cutoff = wall_lowpass_cutoff_amount * wall_to_player_ratio
			if (collider is StaticBody3D and
				collider.physics_material_override and
				collider.physics_material_override is ExpandedPhysicsMaterial):
				bandReductions[0] -= -20*log(1-collider.physics_material_override.band_32_hz)/log(10)
				bandReductions[1] -= -20*log(1-collider.physics_material_override.band_100_hz)/log(10)
				bandReductions[2] -= -20*log(1-collider.physics_material_override.band_320_hz)/log(10)
				bandReductions[3] -= -20*log(1-collider.physics_material_override.band_1000_hz)/log(10)
				bandReductions[4] -= -20*log(1-collider.physics_material_override.band_3200_hz)/log(10)
				bandReductions[5] -= -20*log(1-collider.physics_material_override.band_10000_hz)/log(10)

		lowPassArray.append(_lowpass_cutoff)
	var total = 0;
	for i in range(bandReductions.size()):
		bandReductions[i]/=lowPassArray.size()
	for i in lowPassArray:
		total += i
	total /= lowPassArray.size()
	_target_lowpass_cutoff = total
	_target_32hz_reduction = bandReductions[0]*5.0
	_target_100hz_reduction = bandReductions[1]*5.0
	_target_320hz_reduction = bandReductions[2]*5.0
	_target_1000hz_reduction = bandReductions[3]*5.0
	_target_3200hz_reduction = bandReductions[4]*5.0
	_target_10000hz_reduction = bandReductions[5]*5.0

func _lerp_parameters(delta):
	volume_db = lerp(volume_db, _target_volume_db, delta);
	_lowpass_filter.cutoff_hz = lerp(_lowpass_filter.cutoff_hz, _target_lowpass_cutoff, delta*3.0);
	_reverb_effect.wet = lerp(_reverb_effect.wet, _target_reverb_wetness * max_reverb_wetness, delta * 5.0);
	_reverb_effect.room_size = lerp(_reverb_effect.room_size, _target_reverb_room_size, delta* 5.0);
	_reverb_effect.damping = lerp(_reverb_effect.damping, _target_reverb_dampening, delta*5.0);
	_reverb_effect.predelay_msec = lerp(_reverb_effect.predelay_msec, _target_reverb_reflection_time, delta * 5.0);
	_eq_filter.set_band_gain_db(0, lerp(_eq_filter.get_band_gain_db(0), _target_32hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(1, lerp(_eq_filter.get_band_gain_db(1), _target_100hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(2, lerp(_eq_filter.get_band_gain_db(2), _target_320hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(3, lerp(_eq_filter.get_band_gain_db(3), _target_1000hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(4, lerp(_eq_filter.get_band_gain_db(4), _target_3200hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(5, lerp(_eq_filter.get_band_gain_db(5), _target_10000hz_reduction, delta*3.0))
	#_reverb_effect.predelay_feedback = 0.8
	

func _physics_process(delta):
	_last_update_time += delta

	if _update_distances:
		_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index);
		_current_raycast_index +=1
		if _current_raycast_index >= _distance_array.size():
			_current_raycast_index = 0
			_update_distances = false
	
	if _last_update_time > update_frequency_seconds:
		var player_camera = get_viewport().get_camera_3d()
		if player_camera:
			_on_update_spatial_audio(player_camera);
		_update_distances = true
		_last_update_time = 0.0
	
	_lerp_parameters(delta)
