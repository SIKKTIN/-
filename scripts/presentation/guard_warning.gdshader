shader_type canvas_item;
render_mode unshaded;

uniform vec2 observer;
uniform vec4 zone;
uniform float radius = 210.0;
uniform vec2 facing = vec2(0.0, -1.0);
uniform float half_angle = 3.14159265;
uniform int blocker_count = 0;
uniform vec4 blockers[64];
uniform vec4 edge_color : source_color = vec4(0.88, 0.78, 0.53, 0.48);
uniform float fill_alpha = 0.12;
varying vec2 offset;

void vertex() { offset = VERTEX; }

float ray_hit(vec2 direction, vec4 rect) {
	if (abs(direction.x) < 0.00001 && (observer.x < rect.x || observer.x > rect.x + rect.z)) return -1.0;
	if (abs(direction.y) < 0.00001 && (observer.y < rect.y || observer.y > rect.y + rect.w)) return -1.0;
	vec2 safe_direction = vec2(abs(direction.x) < 0.00001 ? 0.00001 : direction.x, abs(direction.y) < 0.00001 ? 0.00001 : direction.y);
	vec2 a = (rect.xy - observer) / safe_direction;
	vec2 b = (rect.xy + rect.zw - observer) / safe_direction;
	vec2 near_axis = min(a, b);
	vec2 far_axis = max(a, b);
	float near_distance = max(0.0, max(near_axis.x, near_axis.y));
	float far_distance = min(radius, min(far_axis.x, far_axis.y));
	return near_distance <= far_distance ? near_distance : -1.0;
}

void fragment() {
	float distance = length(offset);
	if (distance > radius + 1.5) discard;
	vec2 direction = offset / max(distance, 0.00001);
	float reach = radius;
	if (abs(direction.x) >= 0.00001) reach = min(reach, ((direction.x > 0.0 ? zone.x + zone.z : zone.x) - observer.x) / direction.x);
	if (abs(direction.y) >= 0.00001) reach = min(reach, ((direction.y > 0.0 ? zone.y + zone.w : zone.y) - observer.y) / direction.y);
	for (int i = 0; i < blocker_count; i++) {
		float hit = ray_hit(direction, blockers[i]);
		if (hit >= 0.0) reach = min(reach, hit);
	}
	float remaining = reach - distance;
	if (half_angle < 3.14158) {
		float angle = acos(clamp(dot(direction, facing), -1.0, 1.0));
		remaining = min(remaining, (half_angle - angle) * distance);
	}
	float aa = max(0.35, fwidth(remaining) * 0.5);
	float boundary = 1.0 - smoothstep(0.5, 0.5 + aa, abs(remaining));
	float inside = smoothstep(-aa, aa, remaining);
	COLOR = vec4(edge_color.rgb, max(edge_color.a * boundary, fill_alpha * inside));
}
