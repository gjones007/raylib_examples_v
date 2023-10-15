/*
* Copyright (c) 2019 Chris Camacho (codifies -  http://bedroomcoders.co.uk/)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
*/
// https://bedroomcoders.co.uk/raylib-projecting-3d-onto-2d-handy-for-debugging/
import irishgreencitrus.raylibv as r
import math { cosf, sinf }
import ray
import os

const (
	screen_width  = i32(1280)
	screen_height = i32(720)
	deg2rad       = f32(math.pi / 180)
)

// port of https://www.khronos.org/opengl/wiki/GluProject_and_gluUnProject_code
fn project(pos r.Vector3, mat_view r.Matrix, mat_perps r.Matrix) r.Vector4 {
	mut temp := r.Vector4{
		x: mat_view.m0 * pos.x + mat_view.m4 * pos.y + mat_view.m8 * pos.z + mat_view.m12 // w is always 1
		y: mat_view.m1 * pos.x + mat_view.m5 * pos.y + mat_view.m9 * pos.z + mat_view.m13
		z: mat_view.m2 * pos.x + mat_view.m6 * pos.y + mat_view.m10 * pos.z + mat_view.m14
		w: mat_view.m3 * pos.x + mat_view.m7 * pos.y + mat_view.m11 * pos.z + mat_view.m15
	}

	mut result := r.Vector4{
		x: mat_perps.m0 * temp.x + mat_perps.m4 * temp.y + mat_perps.m8 * temp.z +
			mat_perps.m12 * temp.w
		y: mat_perps.m1 * temp.x + mat_perps.m5 * temp.y + mat_perps.m9 * temp.z +
			mat_perps.m13 * temp.w
		z: mat_perps.m2 * temp.x + mat_perps.m6 * temp.y + mat_perps.m10 * temp.z +
			mat_perps.m14 * temp.w
		w: -temp.z
	}

	if result.w != 0.0 {
		result.w = (1.0 / result.w) / .75 // TODO fudge of .75 WHY???
		// Perspective division
		result.x *= result.w
		result.y *= result.w
		result.z *= result.w
		return result
	} else {
		// result.x = result.y = result.z = result.w
		return result
	}
}

// as we are sorting the array of objects each keeps an "index" to
// identify it...
struct Obj {
mut:
	index i32
	pos   r.Vector3 // required render position
	proj  r.Vector4 // projected 2d position and depth
	m     &r.Model  // which model to use
}

fn main() {
	// Initialization
	//--------------------------------------------------------------------------------------
	r.set_config_flags(r.flag_window_resizable | r.flag_vsync_hint | r.flag_msaa_4x_hint)
	r.init_window(screen_width, screen_height, c'raylib - test')

	// Define the camera to look into our 3d world
	mut camera := r.Camera{
		position: r.Vector3{0.0, 1.0, 0.0}
		target: r.Vector3{0.0, 0.0, 4.0}
		up: r.Vector3{0.0, 1.0, 0.0}
		fovy: 45.0
		projection: r.camera_perspective
	}

	// mut lights := ray.Lights{}
	mut lights := ray.lights_init()

	// r.set_camera_mode(camera, r.camera_first_person)

	mut models := [6]&r.Model{}
	mut objs := [8]Obj{}
	// each model orbits a centre position of its own
	mut base_pos := [8]r.Vector3{}

	for i in 0 .. 8 {
		objs[i].pos = r.Vector3{cosf(0.7853982 * f32(i)) * 4.0, 0, sinf(0.7853982 * f32(i)) * 4.0}
		// bias the cylinder positions
		if i == 2 || i == 6 {
			objs[i].pos.y -= 0.5
		}
		base_pos[i] = objs[i].pos
		objs[i].index = i
	}

	// text to print for each object
	labels := ['torus 1', 'cube 1', 'cylinder 1', 'sphere 1', 'torus 2', 'cube 2', 'cylinder 2',
		'sphere 2']

	mut mesh := r.gen_mesh_torus(.3, 1, 16, 32)
	model0 := r.load_model_from_mesh(mesh)
	models[0] = &model0

	mesh = r.gen_mesh_cube(1, 1, 1)
	model1 := r.load_model_from_mesh(mesh)
	models[1] = &model1

	mesh = r.gen_mesh_cylinder(.5, 1, 32)
	model2 := r.load_model_from_mesh(mesh)
	models[2] = &model2

	mesh = r.gen_mesh_sphere(.5, 16, 32)
	model3 := r.load_model_from_mesh(mesh)
	models[3] = &model3

	// each object shares its shape with another object
	objs[0].m = models[0]
	objs[4].m = models[0]
	objs[1].m = models[1]
	objs[5].m = models[1]
	objs[2].m = models[2]
	objs[6].m = models[2]
	objs[3].m = models[3]
	objs[7].m = models[3]

	// lighting shader
	mut shader := r.load_shader(c'resources/simple_light.vs', c'resources/simple_light.fs')
	shader.locs[r.shader_loc_matrix_model] = r.get_shader_location(shader, c'matModel')
	shader.locs[r.shader_loc_vector_view] = r.get_shader_location(shader, c'viewPos')

	// ambient light level
	amb := r.get_shader_location(shader, c'ambient')

	ambient_col := [f32(0.2), 0.2, 0.2, 1.0]
	r.set_shader_value(shader, amb, ambient_col.data, r.shader_uniform_vec4)

	// set the models shader, texture and position
	tex := r.load_texture(c'resources/test.png')
	for i in 0 .. 4 {
		models[i].materials[0].maps[r.material_map_diffuse].texture = tex
		models[i].materials[0].shader = shader
	}

	// make a light (max 4 but we're only using 1)
	mut light := lights.create_light(ray.light_point, r.Vector3{2, 4, 1}, r.vector3_zero(),
		r.white, shader)

	// frame counter
	mut frame := 0
	// model rotation
	mut ang := r.Vector3{0, 0, 0}

	mut toggle_pos := true
	mut toggle_radar := false

	// SetTargetFPS(60)               // Set  to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	// Detect window close button or ESC key
	for !r.window_should_close() {
		// Update
		//----------------------------------------------------------------------------------

		frame++
		ang.x += 0.01
		ang.y += 0.005
		ang.z -= 0.0025

		// rotate one of the models
		models[0].transform = r.matrix_rotate_xyz(ang)

		r.update_camera(&camera, r.camera_free)

		// these matrices are used to project 3d to 2d
		view := r.matrix_look_at(camera.position, camera.target, camera.up)
		aspect := f32(screen_width) / f32(screen_height)
		perps := r.matrix_perspective(camera.fovy, aspect, 0.01, 1000.0)

		if r.is_key_pressed(r.key_space) {
			toggle_pos = !toggle_pos
		}
		if r.is_key_pressed(r.key_r) {
			toggle_radar = !toggle_radar
		}

		// move the objects around and project the 3d coordinates
		// to 2d for the labels
		for i in 0 .. 8 {
			objs[i].pos = base_pos[objs[i].index]
			mut xi := f32(frame) / 100.0
			// different orbits for alternate objects
			if objs[i].index % 2 == 0 {
				xi = -xi
			}
			mut mi := f32(.25)
			// one object describing a larger orbit
			if objs[i].index == 0 {
				mi = 8
			}
			objs[i].pos.x += cosf(xi) * mi
			objs[i].pos.z += sinf(xi) * mi
			mut p := objs[i].pos
			p.y = if toggle_pos { f32(1.0) } else { f32(0.0) }
			objs[i].proj = project(p, view, perps)
		}

		// as we have no depth buffer in 2d we must depth sort the labels
		// as the array items change place this is why they each need an "index"
		mut sorted := false
		for !sorted {
			sorted = true
			for i in 0 .. 7 {
				if objs[i].proj.w > objs[i + 1].proj.w {
					sorted = false
					tmp := objs[i]
					objs[i] = objs[i + 1]
					objs[i + 1] = tmp
				}
			}
		}
		// position the light slightly above the camera
		light.position = camera.position
		light.position.y += 0.1

		// update the light shader with the camera view position
		r.set_shader_value(shader, shader.locs[r.shader_loc_vector_view], &camera.position.x,
			r.shader_uniform_vec3)
		lights.update_light_values(shader, light)

		// Draw
		//----------------------------------------------------------------------------------
		r.begin_drawing()

		r.clear_background(r.black)

		unsafe { r.begin_mode_3d(&r.Camera3D(&camera)) }

		// render the 3d shapes in any order
		for i in 0 .. 8 {
			r.draw_model(*objs[i].m, objs[i].pos, 1, r.white)
		}

		r.draw_grid(10, 1.0) // Draw a grid

		r.end_mode_3d()

		r.draw_fps(10, 10)

		r.draw_text(c'Space : toggle label position,  R : toggle 3d radar', 140, 10, 20,
			r.darkgreen)

		hsw := f32(screen_width) / 2.0
		hsh := f32(screen_height) / 2.0

		for i in 0 .. 8 {
			mut p := objs[i].proj
			// don't bother drawing if its behind us
			if p.w > 0 {
				// draw the label text centred
				cstr := (labels[i32(objs[i].index)]).str
				mut l := r.measure_text(cstr, 24)
				r.draw_rectangle(i32(hsw + p.x * hsw - 4 - l / 2), i32(hsh - p.y * hsh - 4),
					l + 8, 27, r.blue)
				r.draw_text(cstr, i32(hsw + p.x * hsw - l / 2), i32(hsh - p.y * hsh),
					24, r.white)

				// draw the ground plane coordinates
				// const char* tx = FormatText("%2.3f %2.3f", objs[i].pos.x, objs[i].pos.z)
				tx := '${objs[i].pos.x:2.3}, ${objs[i].pos.z:2.3}'
				l = r.measure_text(tx.str, 24)
				r.draw_rectangle(i32(hsw + p.x * hsw - 4 - l / 2), i32(hsh - p.y * hsh - 4 + 27),
					l + 8, 27, r.blue)
				r.draw_text(tx.str, i32(hsw + p.x * hsw - l / 2), i32(hsh - p.y * hsh + 27),
					24, r.white)
			}
			if toggle_radar {
				// effect the coordinates to give a "3d" radar effect
				p.x /= p.w
				p.y /= p.w
				r.draw_circle(i32(hsw + p.x * (hsw / 32)), i32(screen_height - (hsh / 3) - p.y * (hsh / 32)),
					3, r.red)
			}
		}

		// the contents of the format text will stay intact until the next
		// time FormatText is called as we need the same formatted string
		// twice save the pointer temporarily
		ft := 'Frame ${frame}'
		l := r.measure_text(ft.str, 20)
		r.draw_rectangle(16, 698, l + 8, 42, r.blue)
		r.draw_text(ft.str, 20, 700, 20, r.white)

		r.end_drawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------

	for i in 0 .. 4 {
		r.unload_model(models[i])
	}

	r.unload_texture(tex)
	r.unload_shader(shader)

	r.close_window() // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}
