class_name LandingApproachState
extends RefCounted
## Per-platform visual approach state.
##
## The controller decides WHICH platform is being approached and supplies the
## prediction. This state object owns only the reversible 0..1 timeline and its
## visual target position so platform.gd stays a thin adapter.

const RETRACT_RATE_MULTIPLIER := 0.90

var progress: float = 0.0
var speed_rate: float = 0.0
var target_x: float = 0.5

func reset() -> void:
	progress = 0.0
	speed_rate = 0.0
	target_x = 0.5

func complete() -> void:
	progress = 1.0
	speed_rate = 0.0

func update_forward(
	delta: float,
	time_to_land: float,
	platform_width: float,
	guidance_x: float,
	edge_factor: float,
	platform_global_x: float,
	screen_width: float
) -> void:
	_update_progress(
		delta,
		time_to_land,
		platform_width,
		true
	)
	_set_target_x(
		guidance_x,
		edge_factor,
		platform_width,
		platform_global_x,
		screen_width,
		time_to_land,
		delta
	)

func update_retract(delta: float, platform_width: float) -> void:
	_update_progress(
		delta,
		0.0,
		platform_width,
		false
	)

func _update_progress(
	delta: float,
	time_to_land: float,
	platform_width: float,
	target_confirmed: bool
) -> void:
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, platform_width),
		0.0,
		1.0
	)

	# Width controls the preferred visual tempo, while difficult edge approaches
	# get a little more visual runway. This affects only the feedback animation.
	var edge_factor := clampf(
		absf(target_x - 0.5) * 2.0,
		0.0,
		1.0
	)
	var preferred_duration: float = lerpf(1.35, 0.90, width_factor)
	preferred_duration += lerpf(0.0, 0.22, edge_factor)
	var preferred_rate: float = 1.0 / preferred_duration

	if not target_confirmed:
		# Retraction is deliberately calmer than forward charging. It is a
		# visual "backing away", not a hard reset.
		var retract_rate: float = preferred_rate * RETRACT_RATE_MULTIPLIER
		var retract_response: float = preferred_rate * 8.0

		speed_rate = move_toward(
			speed_rate,
			-retract_rate,
			retract_response * delta
		)
		progress = maxf(
			progress + speed_rate * delta,
			0.0
		)
		return

	if not is_finite(time_to_land) or time_to_land <= 0.0:
		return

	var remaining_progress: float = maxf(1.0 - progress, 0.0)
	var time_buffer: float = lerpf(
		0.04,
		0.14,
		1.0 - width_factor
	)
	var remaining_time: float = maxf(
		time_to_land + time_buffer,
		0.08
	)
	var required_rate: float = remaining_progress / remaining_time

	# Keep the same deliberately capped catch-up behavior as the current
	# prototype; the actual landing event supplies the final 100%.
	var max_catchup_rate: float = preferred_rate * 2.25
	var desired_rate: float = minf(
		required_rate,
		max_catchup_rate
	)

	var rate_response: float = preferred_rate * 8.0
	speed_rate = move_toward(
		speed_rate,
		desired_rate,
		rate_response * delta
	)

	progress = minf(
		progress + speed_rate * delta,
		0.999
	)

func _set_target_x(
	guidance_x: float,
	edge_factor: float,
	platform_width: float,
	platform_global_x: float,
	screen_width: float,
	time_to_land: float,
	delta: float
) -> void:
	var local_x: float = guidance_x - platform_global_x

	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	var base_margin := lerpf(
		0.08,
		0.18,
		clampf(
			inverse_lerp(100.0, 320.0, platform_width),
			0.0,
			1.0
		)
	)

	# Edge predictions are allowed to visually approach the actual corridor
	# instead of being forced into the same interior zone as centered hits.
	var visual_margin := lerpf(
		base_margin,
		0.04,
		clampf(edge_factor, 0.0, 1.0)
	)

	var desired_target_x := clampf(
		(local_x + platform_width * 0.5) / platform_width,
		visual_margin,
		1.0 - visual_margin
	)

	# LandingPredictionFilter is the single visual smoothing layer.
	# Keep this state direct so we do not smooth the same X signal twice.
	target_x = desired_target_x

func charge() -> float:
	var value: float = clampf(progress, 0.0, 1.0)

	if value < 0.20:
		return 0.20 * smoothstep(0.0, 1.0, value / 0.20)
	if value < 0.50:
		return 0.20 + 0.30 * smoothstep(
			0.0,
			1.0,
			(value - 0.20) / 0.30
		)
	if value < 0.70:
		return 0.50 + 0.20 * smoothstep(
			0.0,
			1.0,
			(value - 0.50) / 0.20
		)
	if value < 0.80:
		return 0.70 + 0.10 * smoothstep(
			0.0,
			1.0,
			(value - 0.70) / 0.10
		)
	return 0.80 + 0.20 * smoothstep(
		0.0,
		1.0,
		(value - 0.80) / 0.20
	)
