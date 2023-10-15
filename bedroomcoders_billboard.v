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
import irishgreencitrus.raylibv as r
import math { cosf, sinf }
import os

const (
	screen_width  = i32(1280)
	screen_height = i32(720)
)

fn main() {
	//--------------------------------------------------------------------------
	// Initialization
	//--------------------------------------------------------------------------
	r.set_trace_log_level(r.log_all)
	r.set_config_flags(r.flag_window_resizable | r.flag_vsync_hint | r.flag_msaa_4x_hint)
	r.init_window(screen_width, screen_height, c'raylib - test')

	// Define the camera to look into our 3d world
	mut camera := r.Camera{
		position: r.Vector3{0.0, 2.0, 8.0}
		target: r.Vector3{0.0, 1.0, 0.0}
		up: r.Vector3{0.0, 1.0, 0.0}
		fovy: 45.0
	}

	// textures and shader
	tex := r.load_texture(os.resource_abs_path(os.join_path('resources', 'test.png')).str)
	bill := r.load_texture(os.resource_abs_path(os.join_path('resources', 'billboard.png')).str)
	alpha_discard := r.load_shader(c'', os.resource_abs_path(os.join_path('resources',
		'alpha_discard.fs')).str)

	// a 3D model
	mesh := r.gen_mesh_cube(.7, .7, .7)
	mut model := r.load_model_from_mesh(mesh)
	unsafe {
		model.materials[0].maps[r.material_map_diffuse].texture = tex
	}
	// model rotation
	mut ang := r.Vector3{0, 0, 0}

	//--------------------------------------------------------------------------
	// Main game loop
	//--------------------------------------------------------------------------
	// Detect window close button or ESC key
	for !r.window_should_close() {
		//----------------------------------------------------------------------
		// Update
		//----------------------------------------------------------------------
		ang = r.vector3_add(ang, r.Vector3{0.01, 0.005, 0.0025})
		model.transform = r.matrix_rotate_xyz(ang)
		r.update_camera(&camera, r.camera_orbital)

		//----------------------------------------------------------------------
		// Draw
		//----------------------------------------------------------------------
		r.begin_drawing()

		r.clear_background(r.white)

		unsafe { r.begin_mode_3d(&r.Camera3D(&camera)) }

		// lower 3D model
		r.draw_model(model, r.Vector3{0, 0.5, 0}, 1, r.white)
		r.draw_grid(10, 1.0)

		// blue inner circle
		r.draw_circle_3d(r.vector3_zero(), 1, r.Vector3{1, 0, 0}, 90, r.blue)

		// if space key, isn't held down use the shader
		// space key shows default behaviour
		if !r.is_key_down(r.key_space) {
			r.begin_shader_mode(alpha_discard)
		}

		// two circles of billboards
		mut a := f32(0)
		for a < math.pi * 2 {
			r.draw_billboard(camera, bill, r.Vector3{cosf(a), 1, sinf(a)}, 1.0, r.white)
			r.draw_billboard(camera, bill, r.Vector3{cosf(a - ang.x * 2) * 2, 1, sinf(a - ang.x * 2) * 2},
				1.0, r.white)
			a += math.pi / 4
		}

		if !r.is_key_down(r.key_space) {
			r.end_shader_mode()
		}

		// invert rotation for second cube
		model.transform = r.matrix_invert(model.transform)
		r.draw_model(model, r.Vector3{0, 1.5, 0}, 1, r.white)

		// red outer circle
		r.draw_circle_3d(r.vector3_zero(), 2, r.Vector3{1, 0, 0}, 90, r.red)

		r.end_mode_3d()
		r.draw_fps(10, 10)

		r.end_drawing()
	}

	//--------------------------------------------------------------------------
	// De-Initialization
	//--------------------------------------------------------------------------

	r.unload_model(model)
	r.unload_texture(tex)
	r.unload_texture(bill)

	r.close_window()
}
