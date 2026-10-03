class_name PlatformGeneratorBrain
extends RefCounted

## Describes the current structural phase of platform generation.
enum GenerationPhase {
	BUILD_UP,
	COMMITMENT,
	RELEASE,
	TRANSITION,
	RECOVERY,
}

## Describes the vertical density between patterns/not the real density system
enum VerticalDensity {
	SPARSE,
	NORMAL,
	DENSE
}

enum BiomeType {
	FOREST,
	SKY,
	SPACE
}

enum BiomeSection {
	EARLY,
	MID,
	LATE,
	DEEP
}

## Contains all external inputs that can influence generation difficulty.
class DifficultyContext:
	var world_progress: float = 0.0
	var biome_difficulty: float = 1.0
	var section_difficulty: float = 1.0
	var section_progress: float = 0.0
	
	var current_biome: BiomeType = BiomeType.FOREST
	var current_section: BiomeSection = BiomeSection.EARLY
	
	var performance_score: float = 0.5
	var performance_target: float = 0.5
	
	var performance_modifier: float = 1.0
	var pressure_modifier: float = 1.0
	
	var progression_modifier: float = 1.0
	var mastery_modifier: float = 1.0
	var escalation_modifier: float = 1.0
	
	var mastery_score: float = 0.0
	var progression_level: float = 0.0

	var biome_profile: DifficultyProfile = DifficultyProfile.new()
	var section_profile: DifficultyProfile = DifficultyProfile.new()
	
	var channels: DifficultyChannels = DifficultyChannels.new()

## Defines how difficulty develops throughout a biome or section.
class DifficultyProfile:
	var minimum_intensity: float = 0.0
	var maximum_intensity: float = 1.0

	var early_weight: float = 0.25
	var middle_weight: float = 0.50
	var late_weight: float = 0.75

	var early_intensity: float = 0.25
	var middle_intensity: float = 0.55
	var late_intensity: float = 0.80
	
	var pattern_weight: float = 1.0
	var platform_weight: float = 1.0
	var traversal_weight: float = 1.0
	var density_weight: float = 1.0
	var threat_weight: float = 1.0
	var event_weight: float = 1.0

## Contains the individual difficulty channels produced by the difficulty system.
class DifficultyChannels:
	var pattern: float = 0.0
	var platform: float = 0.0
	var traversal: float = 0.0
	var density: float = 0.0
	var threat: float = 0.0
	var event: float = 0.0

## Section profiles for local difficulty.
class SectionDifficultyProfile:
	var starting_difficulty: float = 0.0
	var ending_difficulty: float = 1.0
	var curve_power: float = 1.0
	var global_multiplier: float = 1.0

const Platform := preload("res://scripts/platform.gd")

## Temporary testing controls for biome section progression.
@export var debug_section_progression: bool = true
@export var debug_section_duration: float = 60.0

var debug_section_timer: float = 0.0

var difficulty_max_score: float

## Stores the current external difficulty inputs used by the Generator Brain.
var difficulty_context: DifficultyContext = DifficultyContext.new()

## Current generation phase used to guide future pattern and pacing decisions.
var generation_phase: GenerationPhase = GenerationPhase.BUILD_UP

## Number of patterns generated during the current phase.
var phase_pattern_count: int = 0

## Remembers recently generated pattern families so repetition can be controlled.
var _pattern_history: Array[PlatformPatterns.PatternType] = []

## Maximum number of recent pattern families the brain remembers.
const PATTERN_HISTORY_SIZE: int = 3

var basic_weight_start: float
var basic_weight_end: float

var pattern_unlock_difficulty: PackedFloat32Array
var pattern_max_weight: PackedFloat32Array

var max_moving_weight: float
var max_breakable_weight: float
var spring_weight: float

var width_shrink_at_max_difficulty: float
var min_width_scale: float
var max_width_scale: float

var vertical_density: VerticalDensity = VerticalDensity.NORMAL
var vertical_density_multiplier: float = 1.0

var force_test_pattern: bool = false
var test_pattern: PlatformPatterns.PatternType = PlatformPatterns.PatternType.BASIC

var forest_profiles: Dictionary = {
	BiomeSection.EARLY: SectionDifficultyProfile.new(),
	BiomeSection.MID: SectionDifficultyProfile.new(),
	BiomeSection.LATE: SectionDifficultyProfile.new(),
	BiomeSection.DEEP: SectionDifficultyProfile.new()
}

func _init(
	p_difficulty_max_score: float,
	p_basic_weight_start: float,
	p_basic_weight_end: float,
	p_pattern_unlock_difficulty: PackedFloat32Array,
	p_pattern_max_weight: PackedFloat32Array,
	p_max_moving_weight: float,
	p_max_breakable_weight: float,
	p_spring_weight: float,
	p_width_shrink_at_max_difficulty: float,
	p_min_width_scale: float,
	p_max_width_scale: float
) -> void:
	difficulty_max_score = p_difficulty_max_score
	basic_weight_start = p_basic_weight_start
	basic_weight_end = p_basic_weight_end
	pattern_unlock_difficulty = p_pattern_unlock_difficulty
	pattern_max_weight = p_pattern_max_weight
	max_moving_weight = p_max_moving_weight
	max_breakable_weight = p_max_breakable_weight
	spring_weight = p_spring_weight
	width_shrink_at_max_difficulty = p_width_shrink_at_max_difficulty
	min_width_scale = p_min_width_scale
	max_width_scale = p_max_width_scale
	
	## Initializes biome and section difficulty profiles.
	_initialize_biome_profiles()


## Temporarily advances through biome sections for difficulty testing.
func update_debug_section_progression(delta: float) -> void:
	if not debug_section_progression:
		return

	debug_section_timer += delta

	var progress: float = clampf(
		debug_section_timer / debug_section_duration,
		0.0,
		1.0
	)

	set_section_progress(progress)

	if debug_section_timer >= debug_section_duration:
		debug_section_timer = 0.0

		match get_current_section():
			BiomeSection.EARLY:
				set_current_section(BiomeSection.MID)
				set_section_progress(0.0)

			BiomeSection.MID:
				set_current_section(BiomeSection.LATE)
				set_section_progress(0.0)

			BiomeSection.LATE:
				set_current_section(BiomeSection.DEEP)
				set_section_progress(0.0)

			BiomeSection.DEEP:
				set_current_section(BiomeSection.EARLY)
				set_section_progress(0.0)


## Creates the difficulty profiles used by the Forest biome sections.
func _initialize_biome_profiles() -> void:
	var early: SectionDifficultyProfile = forest_profiles[BiomeSection.EARLY]
	early.starting_difficulty = 0.05
	early.ending_difficulty = 0.45
	early.curve_power = 1.1
	early.global_multiplier = 1.0

	var mid: SectionDifficultyProfile = forest_profiles[BiomeSection.MID]
	mid.starting_difficulty = 0.10
	mid.ending_difficulty = 0.60
	mid.curve_power = 1.15
	mid.global_multiplier = 1.0

	var late: SectionDifficultyProfile = forest_profiles[BiomeSection.LATE]
	late.starting_difficulty = 0.15
	late.ending_difficulty = 0.75
	late.curve_power = 1.2
	late.global_multiplier = 1.05

	var deep: SectionDifficultyProfile = forest_profiles[BiomeSection.DEEP]
	deep.starting_difficulty = 0.20
	deep.ending_difficulty = 0.90
	deep.curve_power = 1.25
	deep.global_multiplier = 1.10


## Returns the difficulty profile for the currently active biome section.
func _get_current_section_profile() -> SectionDifficultyProfile:
	if difficulty_context.current_biome == BiomeType.FOREST:
		return forest_profiles.get(
			difficulty_context.current_section,
			forest_profiles[BiomeSection.EARLY]
		)

	return forest_profiles[BiomeSection.EARLY]


## Calculates local difficulty from the active section profile and its progress.
func get_section_difficulty() -> float:
	var profile: SectionDifficultyProfile = _get_current_section_profile()

	var progress: float = clampf(
		difficulty_context.section_progress,
		0.0,
		1.0
	)

	var curved_progress: float = pow(
		progress,
		profile.curve_power
	)

	return lerpf(
		profile.starting_difficulty,
		profile.ending_difficulty,
		curved_progress
	) * profile.global_multiplier


## Returns the normalized score contribution to difficulty.
func get_score_difficulty() -> float:
	if difficulty_max_score <= 0.0:
		return 0.0

	return clampf(
		GameManager.current_score / difficulty_max_score,
		0.0,
		1.0
	)


## Returns the base difficulty using score, biome, and local section progression.
func get_base_difficulty() -> float:
	var score_difficulty: float = get_score_difficulty()
	var section_difficulty: float = get_section_difficulty()

	var biome_factor: float = maxf(
		difficulty_context.biome_difficulty,
		0.0
	)

	var biome_profile_intensity: float = get_biome_profile_intensity()

	var biome_curve: float = lerpf(
		1.0,
		biome_factor,
		biome_profile_intensity
	)

	var combined_difficulty: float = maxf(
		score_difficulty,
		section_difficulty
	)

	return clampf(
		combined_difficulty * biome_curve,
		0.0,
		1.0
	)


## Returns the final difficulty after all active difficulty modifiers.
func get_difficulty() -> float:
	var difficulty: float = get_base_difficulty()

	difficulty *= get_combined_difficulty_modifier()

	return clampf(
		difficulty,
		0.0,
		1.0
	)


## Updates the world-level progression input used by the difficulty system.
func set_world_progress(value: float) -> void:
	difficulty_context.world_progress = clampf(value, 0.0, 1.0)


## Updates the biome difficulty multiplier.
func set_biome_difficulty(value: float) -> void:
	difficulty_context.biome_difficulty = maxf(value, 0.0)


## Updates the section difficulty multiplier.
func set_section_difficulty(value: float) -> void:
	difficulty_context.section_difficulty = maxf(value, 0.0)


## Updates the player's progress through the current biome section.
func set_section_progress(value: float) -> void:
	difficulty_context.section_progress = clampf(value, 0.0, 1.0)


## Sets the active biome.
func set_current_biome(biome: BiomeType) -> void:
	difficulty_context.current_biome = biome


## Sets the active section within the current biome.
func set_current_section(section: BiomeSection) -> void:
	difficulty_context.current_section = section


## Updates the player-performance difficulty modifier.
func set_performance_modifier(value: float) -> void:
	difficulty_context.performance_modifier = maxf(value, 0.0)


## Updates the observed player performance level.
func set_performance_score(value: float) -> void:
	difficulty_context.performance_target = clampf(
		value,
		0.0,
		1.0
	)


## Updates the deliberate world-pressure modifier.
func set_pressure_modifier(value: float) -> void:
	difficulty_context.pressure_modifier = maxf(value, 0.0)


## Replaces the active biome difficulty profile.
func set_biome_profile(profile: DifficultyProfile) -> void:
	difficulty_context.biome_profile = profile


## Replaces the active section difficulty profile.
func set_section_profile(profile: DifficultyProfile) -> void:
	difficulty_context.section_profile = profile


## Sets the progression-based difficulty modifier.
func set_progression_modifier(value: float) -> void:
	difficulty_context.progression_modifier = maxf(value, 0.0)


## Sets the mastery-based difficulty modifier.
func set_mastery_modifier(value: float) -> void:
	difficulty_context.mastery_modifier = maxf(value, 0.0)


## Sets the deliberate escalation modifier.
func set_escalation_modifier(value: float) -> void:
	difficulty_context.escalation_modifier = maxf(value, 0.0)


## Sets the player's demonstrated mastery score.
func set_mastery_score(value: float) -> void:
	difficulty_context.mastery_score = clampf(value, 0.0, 1.0)


## Sets the current world progression level.
func set_progression_level(value: float) -> void:
	difficulty_context.progression_level = clampf(value, 0.0, 1.0)


## Returns the active biome.
func get_current_biome() -> BiomeType:
	return difficulty_context.current_biome


## Returns the active section within the current biome.
func get_current_section() -> BiomeSection:
	return difficulty_context.current_section


## Returns the player's progress through the current biome section.
func get_section_progress() -> float:
	return difficulty_context.section_progress


## Returns the current smoothed player performance level.
func get_performance_score() -> float:
	return difficulty_context.performance_score


## Returns the progression difficulty modifier.
func get_progression_modifier() -> float:
	return difficulty_context.progression_modifier


## Returns the mastery difficulty modifier.
func get_mastery_modifier() -> float:
	return difficulty_context.mastery_modifier


## Returns the escalation difficulty modifier.
func get_escalation_modifier() -> float:
	return difficulty_context.escalation_modifier


## Returns the player's demonstrated mastery score.
func get_mastery_score() -> float:
	return difficulty_context.mastery_score


## Returns the current world progression level.
func get_progression_level() -> float:
	return difficulty_context.progression_level


## Returns the combined difficulty modifier with a global safety limit.
func get_combined_difficulty_modifier() -> float:
	var modifier: float = (
		difficulty_context.performance_modifier
		* difficulty_context.pressure_modifier
		* difficulty_context.progression_modifier
		* difficulty_context.mastery_modifier
		* difficulty_context.escalation_modifier
	)

	return clampf(
		modifier,
		0.75,
		1.35
	)


## Updates mastery from the player's recent demonstrated performance.
func update_mastery(delta: float) -> void:
	var performance: float = get_performance_score()

	if performance > 0.65:
		difficulty_context.mastery_score = minf(
			difficulty_context.mastery_score + delta * 0.08,
			1.0
		)
	elif performance < 0.35:
		difficulty_context.mastery_score = maxf(
			difficulty_context.mastery_score - delta * 0.02,
			0.0
		)


## Converts demonstrated mastery into a controlled difficulty modifier.
func update_mastery_modifier() -> void:
	var mastery: float = get_mastery_score()

	difficulty_context.mastery_modifier = lerpf(
		1.0,
		1.15,
		mastery
	)


## Smoothly moves the performance state toward the latest observed performance.
func update_performance(delta: float) -> void:
	var target: float = difficulty_context.performance_target
	var current: float = difficulty_context.performance_score

	var smoothing_speed: float = 0.75

	difficulty_context.performance_score = move_toward(
		current,
		target,
		smoothing_speed * delta
	)


## Converts player performance into a controlled difficulty modifier.
func update_performance_modifier() -> void:
	var performance: float = difficulty_context.performance_score

	var modifier: float = lerpf(
		0.90,
		1.10,
		performance
	)

	difficulty_context.performance_modifier = modifier


## Updates the performance state and converts it into a difficulty modifier.
func update_performance_system(delta: float) -> void:
	update_performance(delta)
	update_performance_modifier()
	
	## Updates long-term mastery separately from short-term performance.
	update_mastery(delta)
	
	## Converts the current mastery level into difficulty pressure.
	update_mastery_modifier()


## Updates temporary world-section testing state.
func update_generation_context(delta: float) -> void:
	update_debug_section_progression(delta)


## Returns the complete difficulty state for debugging and future system integration.
func get_difficulty_snapshot() -> Dictionary:
	var channels: DifficultyChannels = evaluate_difficulty_channels()

	return {
		"score_difficulty": get_score_difficulty(),
		"world_progress": difficulty_context.world_progress,
		"biome_difficulty": difficulty_context.biome_difficulty,
		"section_difficulty": difficulty_context.section_difficulty,
		"section_progress": difficulty_context.section_progress,

		"biome_profile_intensity": get_biome_profile_intensity(),
		"section_profile_intensity": get_section_profile_intensity(),

		"pattern_difficulty": channels.pattern,
		"platform_difficulty": channels.platform,
		"traversal_difficulty": channels.traversal,
		"density_difficulty": channels.density,
		"threat_difficulty": channels.threat,
		"event_difficulty": channels.event,

		"performance_modifier": difficulty_context.performance_modifier,
		"pressure_modifier": difficulty_context.pressure_modifier,
		
		"progression_modifier": difficulty_context.progression_modifier,
		"mastery_modifier": difficulty_context.mastery_modifier,
		"mastery_score": difficulty_context.mastery_score,
		"escalation_modifier": difficulty_context.escalation_modifier,
		"combined_modifier": get_combined_difficulty_modifier(),

		"base_difficulty": get_base_difficulty(),
		"final_difficulty": get_difficulty(),
		
		"performance_score": difficulty_context.performance_score,
		"performance_target": difficulty_context.performance_target,
	}


## Creates a difficulty profile with progression and channel composition.
func create_difficulty_profile(
	early_intensity: float,
	middle_intensity: float,
	late_intensity: float,
	maximum_intensity: float = 1.0,
	pattern_weight: float = 1.0,
	platform_weight: float = 1.0,
	traversal_weight: float = 1.0,
	density_weight: float = 1.0,
	threat_weight: float = 1.0,
	event_weight: float = 1.0
) -> DifficultyProfile:

	var profile: DifficultyProfile = DifficultyProfile.new()

	profile.early_intensity = clampf(
		early_intensity,
		0.0,
		1.0
	)

	profile.middle_intensity = clampf(
		middle_intensity,
		0.0,
		1.0
	)

	profile.late_intensity = clampf(
		late_intensity,
		0.0,
		1.0
	)

	profile.maximum_intensity = clampf(
		maximum_intensity,
		0.0,
		1.0
	)

	profile.pattern_weight = maxf(pattern_weight, 0.0)
	profile.platform_weight = maxf(platform_weight, 0.0)
	profile.traversal_weight = maxf(traversal_weight, 0.0)
	profile.density_weight = maxf(density_weight, 0.0)
	profile.threat_weight = maxf(threat_weight, 0.0)
	profile.event_weight = maxf(event_weight, 0.0)

	return profile


## Evaluates a difficulty profile at the given normalized progress.
func evaluate_difficulty_profile(
	profile: DifficultyProfile,
	progress: float
) -> float:

	var t: float = clampf(progress, 0.0, 1.0)

	if t <= profile.early_weight:
		var early_t: float = inverse_lerp(
			0.0,
			profile.early_weight,
			t
		)

		return lerpf(
			profile.minimum_intensity,
			profile.early_intensity,
			early_t
		)

	if t <= profile.middle_weight:
		var middle_t: float = inverse_lerp(
			profile.early_weight,
			profile.middle_weight,
			t
		)

		return lerpf(
			profile.early_intensity,
			profile.middle_intensity,
			middle_t
		)

	if t <= profile.late_weight:
		var late_t: float = inverse_lerp(
			profile.middle_weight,
			profile.late_weight,
			t
		)

		return lerpf(
			profile.middle_intensity,
			profile.late_intensity,
			late_t
		)

	var final_t: float = inverse_lerp(
		profile.late_weight,
		1.0,
		t
	)

	return lerpf(
		profile.late_intensity,
		profile.maximum_intensity,
		final_t
	)


## Converts profile intensity into the individual difficulty channels.
func evaluate_difficulty_channels() -> DifficultyChannels:
	var channels: DifficultyChannels = DifficultyChannels.new()

	var biome_intensity: float = get_biome_profile_intensity()
	var section_intensity: float = get_section_profile_intensity()

	var combined_intensity: float = (
		biome_intensity + section_intensity
	) * 0.5

	channels.pattern = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.pattern_weight
			+ difficulty_context.section_profile.pattern_weight
		) * 0.5,
		0.0,
		1.0
	)

	channels.platform = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.platform_weight
			+ difficulty_context.section_profile.platform_weight
		) * 0.5,
		0.0,
		1.0
	)

	channels.traversal = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.traversal_weight
			+ difficulty_context.section_profile.traversal_weight
		) * 0.5,
		0.0,
		1.0
	)

	channels.density = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.density_weight
			+ difficulty_context.section_profile.density_weight
		) * 0.5,
		0.0,
		1.0
	)

	channels.threat = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.threat_weight
			+ difficulty_context.section_profile.threat_weight
		) * 0.5,
		0.0,
		1.0
	)

	channels.event = clampf(
		combined_intensity
		* (
			difficulty_context.biome_profile.threat_weight
			+ difficulty_context.section_profile.event_weight
		) * 0.5,
		0.0,
		1.0
	)

	return channels


## Returns the local difficulty generated by the current biome section profile.
func get_local_section_difficulty() -> float:
	return get_section_difficulty()


## Returns the difficulty before player-performance modifiers are applied.
func get_base_generation_difficulty() -> float:
	return get_base_difficulty()


## Returns the current difficulty of pattern generation.
func get_pattern_difficulty() -> float:
	return evaluate_difficulty_channels().pattern


## Returns the current difficulty of platform selection.
func get_platform_difficulty() -> float:
	return evaluate_difficulty_channels().platform


## Returns the current difficulty of traversal demands.
func get_traversal_difficulty() -> float:
	return evaluate_difficulty_channels().traversal


## Returns the current density pressure.
func get_density_difficulty() -> float:
	return evaluate_difficulty_channels().density


## Returns the current threat difficulty.
func get_threat_difficulty() -> float:
	return evaluate_difficulty_channels().threat


## Returns the current event complexity.
func get_event_difficulty() -> float:
	return evaluate_difficulty_channels().event


## Returns a difficulty channel by name for generic future systems.
func get_difficulty_channel(channel_name: String) -> float:
	match channel_name:
		"pattern":
			return get_pattern_difficulty()

		"platform":
			return get_platform_difficulty()

		"traversal":
			return get_traversal_difficulty()

		"density":
			return get_density_difficulty()

		"threat":
			return get_threat_difficulty()

		"event":
			return get_event_difficulty()

		_:
			return get_difficulty()


## Returns the current intensity of the active biome profile.
func get_biome_profile_intensity() -> float:
	return evaluate_difficulty_profile(
		difficulty_context.biome_profile,
		difficulty_context.section_progress
	)


## Returns the current intensity of the active section profile.
func get_section_profile_intensity() -> float:
	return evaluate_difficulty_profile(
		difficulty_context.section_profile,
		difficulty_context.section_progress
	)


## Returns the current generation phase.
func get_generation_phase() -> GenerationPhase:
	return generation_phase


## Defines how strongly each generation phase should favor continuing the current pattern.
func get_phase_pattern_bias() -> Dictionary:
	match generation_phase:
		GenerationPhase.BUILD_UP:
			return {
				"min_patterns": 1,
				"max_patterns": 2,
				"favor_continuation": 0.70,
			}

		GenerationPhase.COMMITMENT:
			return {
				"min_patterns": 2,
				"max_patterns": 3,
				"favor_continuation": 0.85,
			}

		GenerationPhase.RELEASE:
			return {
				"min_patterns": 1,
				"max_patterns": 2,
				"favor_continuation": 0.25,
			}

		GenerationPhase.TRANSITION:
			return {
				"min_patterns": 1,
				"max_patterns": 1,
				"favor_continuation": 0.10,
			}

		GenerationPhase.RECOVERY:
			return {
				"min_patterns": 1,
				"max_patterns": 2,
				"favor_continuation": 0.60,
			}

		_:
			return {
				"min_patterns": 1,
				"max_patterns": 2,
				"favor_continuation": 0.50,
			}


## Determines whether the current generation phase has produced enough patterns to transition.
func is_generation_phase_complete() -> bool:
	var phase_bias: Dictionary = get_phase_pattern_bias()

	var min_patterns: int = int(phase_bias["min_patterns"])
	var max_patterns: int = int(phase_bias["max_patterns"])

	## The phase must always satisfy its minimum duration.
	if phase_pattern_count < min_patterns:
		return false

	## Once the maximum duration is reached, the phase must transition.
	if phase_pattern_count >= max_patterns:
		return true

	## Between minimum and maximum, allow a soft transition chance.
	var progress: float = float(phase_pattern_count - min_patterns) / float(
		max_patterns - min_patterns
	)

	return randf() < progress * 0.35


## Returns how many consecutive times the current pattern family has appeared.
func get_current_pattern_streak() -> int:
	if _pattern_history.is_empty():
		return 0

	var current: PlatformPatterns.PatternType = _pattern_history.back()
	var streak: int = 0

	for i in range(_pattern_history.size() - 1, -1, -1):
		if _pattern_history[i] != current:
			break

		streak += 1

	return streak


## Determines the current vertical pacing state.
func get_vertical_density() -> VerticalDensity:
	var difficulty: float = get_density_difficulty()

	if difficulty < 0.30:
		return VerticalDensity.NORMAL

	if difficulty < 0.60:
		return VerticalDensity.DENSE

	return VerticalDensity.NORMAL


func get_vertical_density_multiplier() -> float:
	match get_vertical_density():
		VerticalDensity.SPARSE:
			return 1.25

		VerticalDensity.NORMAL:
			return 1.0

		VerticalDensity.DENSE:
			return 0.75

	return 1.0


## Advances the generation phase when the current phase has completed its intended pattern span.
func _update_generation_phase() -> void:
	if not is_generation_phase_complete():
		return

	match generation_phase:
		GenerationPhase.BUILD_UP:
			generation_phase = GenerationPhase.COMMITMENT

		GenerationPhase.COMMITMENT:
			generation_phase = GenerationPhase.RELEASE

		GenerationPhase.RELEASE:
			generation_phase = GenerationPhase.TRANSITION

		GenerationPhase.TRANSITION:
			generation_phase = GenerationPhase.RECOVERY

		GenerationPhase.RECOVERY:
			generation_phase = GenerationPhase.BUILD_UP

	phase_pattern_count = 0


## Returns a selection-weight modifier for a pattern based on the current generation phase.
func get_phase_pattern_weight(
	pattern: PlatformPatterns.PatternType
) -> float:

	match generation_phase:

		GenerationPhase.BUILD_UP:
			match pattern:
				PlatformPatterns.PatternType.BASIC:
					return 1.15

				PlatformPatterns.PatternType.ZIGZAG:
					return 1.10

				PlatformPatterns.PatternType.STAIRCASE:
					return 1.10

				PlatformPatterns.PatternType.DIAGONAL:
					return 1.05

				_:
					return 0.90


		GenerationPhase.COMMITMENT:
			match pattern:
				PlatformPatterns.PatternType.CROSS_SCREEN:
					return 1.35

				PlatformPatterns.PatternType.ZIGZAG:
					return 1.20

				PlatformPatterns.PatternType.DIAGONAL:
					return 1.15

				PlatformPatterns.PatternType.STAIRCASE:
					return 1.10

				PlatformPatterns.PatternType.BASIC:
					return 0.75

				_:
					return 1.0


		GenerationPhase.RELEASE:
			match pattern:
				PlatformPatterns.PatternType.BASIC:
					return 1.35

				PlatformPatterns.PatternType.CENTER_EDGE:
					return 1.15

				PlatformPatterns.PatternType.STAIRCASE:
					return 1.05

				_:
					return 0.85


		GenerationPhase.TRANSITION:
			match pattern:
				PlatformPatterns.PatternType.BASIC:
					return 2.0

				PlatformPatterns.PatternType.CENTER_EDGE:
					return 1.15

				_:
					return 0.65


		GenerationPhase.RECOVERY:
			match pattern:
				PlatformPatterns.PatternType.BASIC:
					return 1.60

				PlatformPatterns.PatternType.STAIRCASE:
					return 1.10

				PlatformPatterns.PatternType.CENTER_EDGE:
					return 1.15

				_:
					return 0.80

	return 1.0


func get_generation_density() -> Dictionary:
	var density: VerticalDensity = get_vertical_density()
	
	return {
		"state": density,
		"multiplier": get_vertical_density_multiplier(),
	}


## Chooses the next pattern family using difficulty, history, and generation context.
func choose_pattern_type() -> PlatformPatterns.PatternType:
	## Checks whether the previous generation phase has completed before choosing the next pattern.
	_update_generation_phase()
	
	if force_test_pattern:
		return test_pattern

	## Uses the dedicated pattern difficulty channel for pattern selection.
	var difficulty: float = get_pattern_difficulty()
	
	var phase_bias: Dictionary = get_phase_pattern_bias()
	var favor_continuation: float = float(phase_bias["favor_continuation"])
	var current_streak: int = get_current_pattern_streak()

	var types: Array[PlatformPatterns.PatternType] = [
		PlatformPatterns.PatternType.BASIC
	]

	var weights: Array[float] = [
		lerp(basic_weight_start, basic_weight_end, difficulty)
		* get_phase_pattern_weight(PlatformPatterns.PatternType.BASIC)
	]

	for i in pattern_unlock_difficulty.size():
		var unlock: float = pattern_unlock_difficulty[i]

		if difficulty < unlock:
			continue

		var span: float = maxf(1.0 - unlock, 0.001)

		var weight: float = pattern_max_weight[i] * clampf(
			(difficulty - unlock) / span,
			0.0,
			1.0
		)

		weight *= get_phase_pattern_weight(
			i + 1 as PlatformPatterns.PatternType
		)

		if weight <= 0.0:
			continue

		types.append((i + 1) as PlatformPatterns.PatternType)
		weights.append(weight)

	## Adjusts pattern weights according to the current generation phase.
	if not _pattern_history.is_empty():
		var current_pattern: PlatformPatterns.PatternType = _pattern_history.back()

		for i in types.size():
			if types[i] == current_pattern:
				weights[i] *= lerpf(1.0, 1.5, favor_continuation)
			elif current_streak > 1:
				weights[i] *= lerpf(1.0, 1.25, 1.0 - favor_continuation)
	
	## Softly reduces patterns that appeared recently.
	for i in types.size():
		weights[i] *= _get_pattern_history_multiplier(types[i])

	var total: float = 0.0

	for weight in weights:
		total += weight

	if total <= 0.0:
		return PlatformPatterns.PatternType.BASIC

	var roll: float = randf_range(0.0, total)

	for i in weights.size():
		if roll < weights[i]:
			var selected: PlatformPatterns.PatternType = types[i]
			
			_remember_pattern(selected)
			phase_pattern_count += 1

			return selected

		roll -= weights[i]

	return PlatformPatterns.PatternType.BASIC


## Returns a soft weight penalty based on how recently a pattern was used.
func _get_pattern_history_multiplier(
	pattern: PlatformPatterns.PatternType
) -> float:

	if _pattern_history.is_empty():
		return 1.0

	if _pattern_history[0] == pattern:
		return 0.35

	if _pattern_history.size() > 1 and _pattern_history[1] == pattern:
		return 0.60

	if _pattern_history.size() > 2 and _pattern_history[2] == pattern:
		return 0.80

	return 1.0


## Adds a newly selected pattern to the recent pattern history.
func _remember_pattern(pattern: PlatformPatterns.PatternType) -> void:
	_pattern_history.push_front(pattern)

	if _pattern_history.size() > PATTERN_HISTORY_SIZE:
		_pattern_history.pop_back()


## Returns the pattern that was generated immediately before the current one.
func get_previous_pattern() -> PlatformPatterns.PatternType:
	if _pattern_history.size() < 2:
		return PlatformPatterns.PatternType.BASIC

	return _pattern_history[1]


## Chooses an entry mode based on the current pattern, previous pattern, and generation phase.
func choose_entry_mode(
	pattern: PlatformPatterns.PatternType,
	previous_pattern: PlatformPatterns.PatternType
) -> PlatformPatterns.EntryMode:

	## First pattern of the run has no real previous-pattern context.
	if _pattern_history.size() < 2:
		return _default_entry_mode(pattern)

	## Repeating the same family should usually continue its existing direction.
	if previous_pattern == pattern:
		match generation_phase:
			GenerationPhase.RELEASE:
				return PlatformPatterns.EntryMode.ADAPTIVE

			GenerationPhase.TRANSITION:
				return PlatformPatterns.EntryMode.ADAPTIVE

			_:
				return PlatformPatterns.EntryMode.CONTINUE

	## Strong pattern-to-pattern handoffs take priority over generic phase behavior.
	match previous_pattern:

		PlatformPatterns.PatternType.CROSS_SCREEN:
			## Cross-screen naturally hands the player back toward the opposite side.
			return PlatformPatterns.EntryMode.OPPOSITE

		PlatformPatterns.PatternType.CENTER_EDGE:
			if pattern == PlatformPatterns.PatternType.STAIRCASE:
				## Center-edge naturally hands a staircase back through the center.
				return PlatformPatterns.EntryMode.CENTER

		PlatformPatterns.PatternType.STAIRCASE:
			if pattern == PlatformPatterns.PatternType.CROSS_SCREEN:
				## Staircase into cross-screen preserves the directional commitment.
				return PlatformPatterns.EntryMode.OPPOSITE

		PlatformPatterns.PatternType.ZIGZAG:
			if pattern == PlatformPatterns.PatternType.CROSS_SCREEN:
				## Zigzag into cross-screen continues the established side-to-side movement.
				return PlatformPatterns.EntryMode.OPPOSITE

		_:
			pass

	## Chooses the handoff based on the previous/current pattern combination and phase.
	match generation_phase:

		GenerationPhase.BUILD_UP:
			## Build-up favors smooth continuation unless the previous pattern already creates commitment.
			match [previous_pattern, pattern]:

				[PlatformPatterns.PatternType.BASIC, PlatformPatterns.PatternType.DIAGONAL]:
					return PlatformPatterns.EntryMode.CONTINUE

				[PlatformPatterns.PatternType.BASIC, PlatformPatterns.PatternType.STAIRCASE]:
					return PlatformPatterns.EntryMode.CONTINUE

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.DIAGONAL]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.DIAGONAL]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				_:
					return _default_entry_mode(pattern)


		GenerationPhase.COMMITMENT:
			## Commitment strengthens directional handoffs between compatible pattern families.
			match [previous_pattern, pattern]:

				[PlatformPatterns.PatternType.BASIC, PlatformPatterns.PatternType.ZIGZAG]:
					return PlatformPatterns.EntryMode.OPPOSITE

				[PlatformPatterns.PatternType.STAIRCASE, PlatformPatterns.PatternType.ZIGZAG]:
					return PlatformPatterns.EntryMode.OPPOSITE

				[PlatformPatterns.PatternType.DIAGONAL, PlatformPatterns.PatternType.ZIGZAG]:
					return PlatformPatterns.EntryMode.OPPOSITE

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.CROSS_SCREEN]:
					return PlatformPatterns.EntryMode.OPPOSITE

				[PlatformPatterns.PatternType.DIAGONAL, PlatformPatterns.PatternType.CROSS_SCREEN]:
					return PlatformPatterns.EntryMode.OPPOSITE

				_:
					return _default_entry_mode(pattern)


		GenerationPhase.RELEASE:
			## Release deliberately softens strong previous-to-current commitments.
			match [previous_pattern, pattern]:

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.CENTER_EDGE]:
					return PlatformPatterns.EntryMode.CENTER

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.CENTER_EDGE]:
					return PlatformPatterns.EntryMode.CENTER

				[PlatformPatterns.PatternType.STAIRCASE, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				_:
					return PlatformPatterns.EntryMode.ADAPTIVE


		GenerationPhase.TRANSITION:
			## Transition uses neutral handoffs to deliberately change the spatial language.
			match [previous_pattern, pattern]:

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.CENTER_EDGE]:
					return PlatformPatterns.EntryMode.CENTER

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.CENTER_EDGE]:
					return PlatformPatterns.EntryMode.CENTER

				[PlatformPatterns.PatternType.DIAGONAL, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.STAIRCASE, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				_:
					return PlatformPatterns.EntryMode.ADAPTIVE


		GenerationPhase.RECOVERY:
			## Recovery favors forgiving handoffs after demanding previous/current combinations.
			match [previous_pattern, pattern]:

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.CROSS_SCREEN, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.DIAGONAL, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.STAIRCASE, PlatformPatterns.PatternType.BASIC]:
					return PlatformPatterns.EntryMode.ADAPTIVE

				[PlatformPatterns.PatternType.ZIGZAG, PlatformPatterns.PatternType.STAIRCASE]:
					return PlatformPatterns.EntryMode.CONTINUE

				[PlatformPatterns.PatternType.DIAGONAL, PlatformPatterns.PatternType.STAIRCASE]:
					return PlatformPatterns.EntryMode.CONTINUE

				_:
					return _default_entry_mode(pattern)

	## Final safety fallback for any unexpected generation phase.
	return _default_entry_mode(pattern)


## Provides the natural entry mode when no special transition rule is needed.
func _default_entry_mode(
	pattern: PlatformPatterns.PatternType
) -> PlatformPatterns.EntryMode:

	match pattern:
		PlatformPatterns.PatternType.ZIGZAG:
			return PlatformPatterns.EntryMode.OPPOSITE

		PlatformPatterns.PatternType.STAIRCASE:
			return PlatformPatterns.EntryMode.CONTINUE

		PlatformPatterns.PatternType.DIAGONAL:
			return PlatformPatterns.EntryMode.CONTINUE

		PlatformPatterns.PatternType.CROSS_SCREEN:
			return PlatformPatterns.EntryMode.OPPOSITE

		PlatformPatterns.PatternType.CENTER_EDGE:
			return PlatformPatterns.EntryMode.CENTER

		PlatformPatterns.PatternType.BASIC:
			return PlatformPatterns.EntryMode.ADAPTIVE

		PlatformPatterns.PatternType.RISK:
			return PlatformPatterns.EntryMode.ADAPTIVE

		_:
			return PlatformPatterns.EntryMode.NONE


## Chooses the next platform type using difficulty and platform history.
func choose_platform_type(last_type: int) -> int:
	## Uses the dedicated platform difficulty channel for platform type selection.
	var difficulty: float = get_platform_difficulty()

	var weight_moving: float = max_moving_weight * difficulty
	var weight_breakable: float = max_breakable_weight * difficulty
	var weight_spring: float = spring_weight

	if last_type == Platform.PlatformType.BREAKABLE:
		weight_breakable = 0.0

	var weight_normal: float = maxf(
		1.0 - weight_moving - weight_breakable - weight_spring,
		0.1
	)

	var total: float = (
		weight_normal
		+ weight_moving
		+ weight_breakable
		+ weight_spring
	)

	var roll: float = randf_range(0.0, total)

	if roll < weight_normal:
		return Platform.PlatformType.NORMAL

	roll -= weight_normal

	if roll < weight_moving:
		return Platform.PlatformType.MOVING

	roll -= weight_moving

	if roll < weight_breakable:
		return Platform.PlatformType.BREAKABLE

	return Platform.PlatformType.SPRING


func scale_width_scale(base_scale: float) -> float:
	## Scales platform width using the dedicated platform difficulty channel.
	var difficulty: float = get_platform_difficulty()

	var shrunk: float = base_scale * lerp(
		1.0,
		width_shrink_at_max_difficulty,
		difficulty
	)

	return clampf(
		shrunk,
		min_width_scale,
		max_width_scale
	)
