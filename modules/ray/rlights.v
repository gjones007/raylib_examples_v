module ray

/**********************************************************************************************
*
*   raylib.lights - Some useful functions to deal with lights data
*
*   CONFIGURATION:
*
*   #define RLIGHTS_IMPLEMENTATION
*       Generates the implementation of the library into the included file.
*       If not defined, the library is in header only mode and can be included in other headers
*       or source files without problems. But only ONE file should hold the implementation.
*
*   LICENSE: zlib/libpng
*
*   Copyright (c) 2017-2023 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
*
*   This software is provided "as-is", without any express or implied warranty. In no event
*   will the authors be held liable for any damages arising from the use of this software.
*
*   Permission is granted to anyone to use this software for any purpose, including commercial
*   applications, and to alter it and redistribute it freely, subject to the following restrictions:
*
*     1. The origin of this software must not be misrepresented you must not claim that you
*     wrote the original software. If you use this software in a product, an acknowledgment
*     in the product documentation would be appreciated but is not required.
*
*     2. Altered source versions must be plainly marked as such, and must not be misrepresented
*     as being the original software.
*
*     3. This notice may not be removed or altered from any source distribution.
*
**********************************************************************************************/
import irishgreencitrus.raylibv as r

// Defines and Macros
//----------------------------------------------------------------------------------
// Max dynamic lights supported by shader
const max_lights = 4

// Light type
pub const (
	light_directional = 0
	light_point       = 1
)

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

pub struct Lights {
mut:
	light []Light
}

// Light data
pub struct Light {
pub mut:
	@type       i32
	enabled     bool
	position    r.Vector3
	target      r.Vector3
	color       r.Color
	attenuation f32
	// Shader locations
	enabled_loc     i32
	type_loc        i32
	position_loc    i32
	target_loc      i32
	color_loc       i32
	attenuation_loc i32
}

pub fn lights_init() Lights {
	return Lights{
		light: []Light{len: ray.max_lights, cap: ray.max_lights}
	}
}

// Create a light and get shader locations
pub fn (mut l Lights) create_light(@type i32, position r.Vector3, target r.Vector3, color r.Color, shader r.Shader) &Light {
	mut len := l.light.len
	if len < ray.max_lights {
		l.light.grow_len(1)
		l.light[len] = Light{
			enabled: true
			@type: @type
			position: position
			target: target
			color: color
			// NOTE: Lighting shader naming must be the provided ones
			enabled_loc: r.get_shader_location(shader, 'light[${len}].enabled'.str)
			type_loc: r.get_shader_location(shader, 'light[${len}].type'.str)
			position_loc: r.get_shader_location(shader, 'light[${len}].position'.str)
			target_loc: r.get_shader_location(shader, 'light[${len}].target'.str)
			color_loc: r.get_shader_location(shader, 'light[${len}].color'.str)
		}
		l.update_light_values(shader, l.light[len])
	}
	return &l.light[len - 1]
}

// Send light properties to shader
// NOTE: Light shader locations should be available
pub fn (mut l Lights) update_light_values(shader r.Shader, light Light) {
	// Send to shader light enabled state and type
	r.set_shader_value(shader, light.enabled_loc, &light.enabled, r.shader_uniform_int)
	r.set_shader_value(shader, light.type_loc, &light.@type, r.shader_uniform_int)

	// Send to shader light position values
	position := r.Vector3{light.position.x, light.position.y, light.position.z}
	r.set_shader_value(shader, light.position_loc, position, r.shader_uniform_vec3)

	// Send to shader light target position values
	target := r.Vector3{light.target.x, light.target.y, light.target.z}
	r.set_shader_value(shader, light.target_loc, target, r.shader_uniform_vec3)

	// Send to shader light color values
	color := r.Vector4{f32(light.color.r) / f32(255), f32(light.color.g) / f32(255), f32(light.color.b) / f32(255), f32(light.color.a) / f32(255)}
	r.set_shader_value(shader, light.color_loc, color, r.shader_uniform_vec4)
}
