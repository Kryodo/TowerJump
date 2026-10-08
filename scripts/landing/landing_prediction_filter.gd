class_name LandingPredictionFilter
extends RefCounted
## Filters only the visual landing-position signal.
##
## Raw physics prediction remains the source of truth. This layer suppresses
## high-frequency left/right oscillation in the visual target, while sustained
## movement is allowed to move the target quickly. It never changes platform
## identity, landing time, or ball physics.

const NORMAL_RESPONSE := 36.0
const OSCILLATION_RESPONSE := 18.0
const REVERSAL_WINDOW := 0.12
const REVERSAL_DECAY := 5.0
const REVERSAL_GAIN := 0.35
const REVERSAL_DELTA_THRESHOLD := 0.025

var _initialized: bool = false
var _filtered_local_x: float = 0.0
var _last_raw_local_x: float = 0.0
var _last_raw_delta: float = 0.0
var _reversal_energy: float = 0.0
var _reversal_age: float = INF

func reset() -> void:
	_initialized = false
	_filtered_local_x = 0.0
	_last_raw_local_x = 0.0
	_last_raw_delta = 0.0
	_reversal_energy = 0.0
	_reversal_age = INF

func update(
	raw_world_x: float,
	platform_world_x: float,
	screen_width: float,
	platform_width: float,
	delta: float
) -> float:
	var raw_local_x := _shortest_local_x(
		raw_world_x,
		platform_world_x,
		screen_width
	)

	if not _initialized:
		_initialized = true
		_filtered_local_x = raw_local_x
		_last_raw_local_x = raw_local_x
		_last_raw_delta = 0.0
		_reversal_energy = 0.0
		_reversal_age = INF
		return _wrap_x(
			platform_world_x + _filtered_local_x,
			screen_width
		)

	var raw_delta := raw_local_x - _last_raw_local_x
	var platform_scale := maxf(platform_width, 1.0)
	var normalized_delta := raw_delta / platform_scale

	_reversal_age += delta
	_reversal_energy = maxf(
		_reversal_energy - REVERSAL_DECAY * delta,
		0.0
	)

	# A reversal only counts as meaningful when the prediction actually moved
	# a noticeable fraction of this platform. Tiny numerical jitter is ignored.
	if (
		absf(normalized_delta) >= REVERSAL_DELTA_THRESHOLD
		and absf(_last_raw_delta) >= platform_scale * REVERSAL_DELTA_THRESHOLD
		and signf(raw_delta) != signf(_last_raw_delta)
		and _reversal_age <= REVERSAL_WINDOW
	):
		_reversal_energy = minf(
			_reversal_energy + REVERSAL_GAIN,
			1.0
		)

	_reversal_age = 0.0 if absf(raw_delta) >= platform_scale * REVERSAL_DELTA_THRESHOLD else _reversal_age

	# Keep sustained directional movement responsive; only rapid reversals slow
	# the visual interpretation. This is intentionally much less conservative
	# than filtering the player's actual steering input.
	var response_rate := lerpf(
		NORMAL_RESPONSE,
		OSCILLATION_RESPONSE,
		_reversal_energy
	)
	var response := 1.0 - exp(-response_rate * maxf(delta, 0.0))

	_filtered_local_x = lerpf(
		_filtered_local_x,
		raw_local_x,
		response
	)

	_last_raw_local_x = raw_local_x
	_last_raw_delta = raw_delta

	return _wrap_x(
		platform_world_x + _filtered_local_x,
		screen_width
	)

func get_last_filtered_world_x(
	platform_world_x: float,
	screen_width: float
) -> float:
	if not _initialized:
		return _wrap_x(platform_world_x, screen_width)

	return _wrap_x(
		platform_world_x + _filtered_local_x,
		screen_width
	)

func _shortest_local_x(
	world_x: float,
	platform_x: float,
	screen_width: float
) -> float:
	var local_x := world_x - platform_x

	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	return local_x

func _wrap_x(x: float, screen_width: float) -> float:
	if screen_width <= 0.0:
		return x

	var wrapped := fmod(x, screen_width)
	if wrapped < 0.0:
		wrapped += screen_width

	return wrapped
