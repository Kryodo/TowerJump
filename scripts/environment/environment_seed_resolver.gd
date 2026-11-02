class_name EnvironmentSeedResolver
extends RefCounted
## Derives repeatable local seeds from stable identities.
## This avoids coupling fixed sections/landmarks to earlier random draw counts.

const FNV_OFFSET_BASIS: int = 2166136261
const FNV_PRIME: int = 16777619
const UINT32_MASK: int = 0xFFFFFFFF
const MAX_POSITIVE_SEED: int = 2147483646


static func section_seed(
	world_seed: int,
	zone_id: StringName,
	subzone_id: StringName,
	stable_section_key: StringName
) -> int:
	var stable_key := "section|%s|%s|%s" % [
		String(zone_id),
		String(subzone_id),
		String(stable_section_key),
	]
	return _resolve(world_seed, stable_key)


static func landmark_seed(
	world_seed: int,
	zone_id: StringName,
	landmark_id: StringName,
	neighborhood_key: StringName
) -> int:
	var stable_key := "landmark|%s|%s|%s" % [
		String(zone_id),
		String(landmark_id),
		String(neighborhood_key),
	]
	return _resolve(world_seed, stable_key)


static func _resolve(world_seed: int, stable_key: String) -> int:
	# FNV-1a over the world seed and stable identity; explicitly avoids
	# engine-global random state and order-dependent random draw sequences.
	var input_bytes := ("%d|%s" % [world_seed, stable_key]).to_utf8_buffer()
	var hash_value: int = FNV_OFFSET_BASIS

	for byte_value in input_bytes:
		hash_value = ((hash_value ^ int(byte_value)) * FNV_PRIME) & UINT32_MASK

	return int(hash_value % MAX_POSITIVE_SEED) + 1
