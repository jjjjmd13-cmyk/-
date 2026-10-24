# Demo of the 3D-to-sprite pipeline: a blocky stand-in knight with joints,
# walk + attack cycles rendered as 8 transparent 384 px frames each.
#   blender -b -noaudio --python tools/blender/knight_demo.py -- <out_dir>
import bpy, math, sys
out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, rgb, metal=0.0, rough=0.5, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    return m

STEEL = mat("steel", (0.55, 0.57, 0.62), 0.9, 0.35)
DARK = mat("dark", (0.12, 0.11, 0.12), 0.6, 0.5)
RED = mat("red", (0.5, 0.04, 0.06), 0.0, 0.8)
GOLD = mat("gold", (0.85, 0.6, 0.2), 1.0, 0.3)
SKIN = mat("skin", (0.75, 0.52, 0.4), 0.0, 0.6)
HAIR = mat("hair", (0.2, 0.12, 0.07), 0.0, 0.8)
BLADE = mat("blade", (0.8, 0.82, 0.86), 1.0, 0.15)

def pivot(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.rotation_mode = "XYZ"
    return e

def part(kind, parent, size, offset, m, rot=(0, 0, 0)):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=20)
    o = bpy.context.active_object
    o.scale = size
    o.location = offset
    o.rotation_euler = rot
    o.parent = parent
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    bev = o.modifiers.new("bevel", "BEVEL")
    bev.width = 0.03
    bev.segments = 2
    return o

root = pivot("root")
hips = pivot("hips", root, (0, 0, 1.0))
part("box", hips, (0.36, 0.26, 0.22), (0, 0, 0), DARK)
torso = pivot("torso", hips, (0, 0, 0.1))
part("box", torso, (0.42, 0.3, 0.55), (0, 0, 0.32), STEEL)
part("box", torso, (0.44, 0.31, 0.06), (0, 0, 0.08), GOLD)
part("cyl", torso, (0.06, 0.06, 0.04), (0.17, 0, 0.42), GOLD, (0, math.pi / 2, 0))
for side in (-1, 1):
    part("ball", torso, (0.16, 0.16, 0.12), (0, side * 0.24, 0.62), STEEL)
part("box", torso, (0.05, 0.42, 0.75), (-0.22, 0, 0.25), RED, (0, 0.18, 0))
head = pivot("head", torso, (0, 0, 0.72))
part("ball", head, (0.15, 0.14, 0.17), (0.02, 0, 0.14), SKIN)
part("ball", head, (0.16, 0.15, 0.1), (-0.02, 0, 0.24), HAIR)

def leg(side):
    thigh = pivot("thigh%d" % side, hips, (0, side * 0.12, -0.05))
    part("cyl", thigh, (0.09, 0.09, 0.22), (0, 0, -0.22), DARK)
    knee = pivot("knee%d" % side, thigh, (0, 0, -0.45))
    part("ball", knee, (0.1, 0.1, 0.09), (0, 0, 0), STEEL)
    part("cyl", knee, (0.08, 0.08, 0.2), (0, 0, -0.21), STEEL)
    part("box", knee, (0.24, 0.12, 0.08), (0.06, 0, -0.44), DARK)
    return thigh, knee

def arm(side):
    sh = pivot("shoulder%d" % side, torso, (0, side * 0.27, 0.58))
    part("cyl", sh, (0.07, 0.07, 0.17), (0, 0, -0.17), STEEL)
    el = pivot("elbow%d" % side, sh, (0, 0, -0.34))
    part("cyl", el, (0.065, 0.065, 0.15), (0, 0, -0.15), STEEL)
    part("ball", el, (0.08, 0.08, 0.08), (0, 0, -0.33), DARK)
    return sh, el

legs = {s: leg(s) for s in (-1, 1)}
arms = {s: arm(s) for s in (-1, 1)}
# Greatsword in the near (camera-side) hand.
sword = pivot("sword", arms[-1][1], (0, 0, -0.34))
part("box", sword, (0.06, 0.04, 1.1), (0, 0, -0.55), BLADE)
part("box", sword, (0.08, 0.3, 0.05), (0, 0, -0.02), GOLD)
part("cyl", sword, (0.03, 0.03, 0.12), (0, 0, 0.1), RED)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 3.4
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0, -8, 1.25)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.camera = cam
for name, loc, energy in (("key", (3, -4, 5), 900), ("rim", (-4, 3, 3), 600), ("fill", (-2, -5, 1), 200)):
    l = bpy.data.lights.new(name, "AREA")
    l.energy = energy
    l.size = 3
    lo = bpy.data.objects.new(name, l)
    lo.location = loc
    lo.rotation_euler = (math.radians(45), 0, math.atan2(loc[0], -loc[1]))
    scene.collection.objects.link(lo)
    lo.constraints.new("TRACK_TO").target = hips

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = False
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 384
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.05, 0.05, 0.06)

def pose_walk(k):
    p = k * 2 * math.pi
    for s in (-1, 1):
        ph = p + (0 if s == -1 else math.pi)
        thigh, knee = legs[s]
        thigh.rotation_euler = (0, math.radians(32) * math.sin(ph), 0)
        knee.rotation_euler = (0, math.radians(-55) * max(0.0, math.sin(ph + 1.4)), 0)
        sh, el = arms[s]
        swing = math.radians(-26) * math.sin(ph)
        sh.rotation_euler = (0, swing if s == 1 else math.radians(20) + swing * 0.4, 0)
        el.rotation_euler = (0, math.radians(-25), 0)
    hips.location.z = 1.0 + 0.05 * abs(math.cos(p))
    torso.rotation_euler = (math.radians(3) * math.sin(p), math.radians(8), 0)
    sword.rotation_euler = (0, math.radians(-115), 0)

def pose_attack(k):
    # wind up (0-0.35), strike (0.35-0.6), follow through and recover.
    if k < 0.35:
        a = k / 0.35
        sh_ang, tw = -150 * a, -15 * a
    elif k < 0.6:
        a = (k - 0.35) / 0.25
        sh_ang, tw = -150 + 230 * a, -15 + 35 * a
    else:
        a = (k - 0.6) / 0.4
        sh_ang, tw = 80 - 80 * a, 20 - 20 * a
    for s in (-1, 1):
        thigh, knee = legs[s]
        thigh.rotation_euler = (0, math.radians(22 * -s), 0)
        knee.rotation_euler = (0, math.radians(-18 if s == 1 else 0), 0)
    sh, el = arms[-1]
    sh.rotation_euler = (0, math.radians(sh_ang), 0)
    el.rotation_euler = (0, math.radians(-20), 0)
    arms[1][0].rotation_euler = (0, math.radians(sh_ang * 0.7), 0)
    torso.rotation_euler = (0, math.radians(tw), 0)
    hips.location.z = 0.95
    sword.rotation_euler = (0, math.radians(-90), 0)

for anim, fn in (("walk", pose_walk), ("attack", pose_attack)):
    for i in range(8):
        fn(i / 8.0)
        bpy.context.view_layer.update()
        scene.render.filepath = "%s/%s_%d.png" % (out, anim, i)
        bpy.ops.render.render(write_still=True)
print("DEMO DONE")
