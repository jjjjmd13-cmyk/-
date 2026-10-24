"""Build an articulated 3D Leon and render the game's actual sprite strips.

Blender 4.2: blender -b --python tools/blender/knight_production.py -- OUTPUT
Optional: --preview renders one studio image before the animation batch.
Reference: Leon's silver/gold lion armor, fur collar, crimson cloak, greatsword.
All geometry/materials are constructed here; renders contain real joint motion.
"""
import bpy
import math
import random
import sys
import json
from pathlib import Path
from mathutils import Vector

ARGS = sys.argv[sys.argv.index('--') + 1:]
OUT = Path(ARGS[0]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = '--preview' in ARGS
random.seed(27)
bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene
JOINTS = {}


def material(name, rgb, metallic=0, roughness=0.5, noise=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    shader = nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if noise:
        tex = nodes.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = 115 if metallic else 65
        tex.inputs['Detail'].default_value = 2
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = noise
        bump.inputs['Distance'].default_value = 0.012
        m.node_tree.links.new(tex.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    return m


STEEL = material('Weathered silver plate', (.38, .43, .49), .82, .33, .16)
EDGE = material('Polished armor edges', (.65, .70, .75), .85, .24)
GOLD = material('Antique engraved gold', (.53, .31, .095), .82, .3, .1)
GOLD_HI = material('Gold filigree highlights', (.8, .57, .24), .78, .28)
MAIL = material('Charcoal chainmail', (.055, .065, .073), .6, .53, .3)
LEATHER = material('Worn brown leather', (.065, .032, .018), 0, .72, .25)
CRIMSON = material('Crimson woven cloth', (.24, .012, .022), 0, .88, .2)
LINING = material('Cape inner lining', (.075, .005, .009), 0, .92)
SKIN = material('Warm skin', (.47, .265, .17), 0, .58, .08)
SKIN_HI = material('Cheek highlights', (.56, .32, .22), 0, .57)
HAIR = material('Dark brown hair', (.04, .014, .006), 0, .58)
FUR = material('Ivory wolf fur', (.47, .38, .27), 0, .95)
FUR_HI = material('Fur highlights', (.72, .61, .44), 0, .93)
EYE = material('Eyes', (.018, .012, .008), 0, .3)
BLADE = material('Sword tempered steel', (.58, .64, .71), .92, .23, .045)
FULLER = material('Blade fuller', (.22, .27, .32), .86, .28)


def pivot(name, parent=None, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    SCENE.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    obj.rotation_mode = 'XYZ'
    JOINTS[name] = obj
    return obj


def finish(obj, name, parent, loc, mat, smooth=True):
    obj.name = name
    obj.parent = parent
    obj.location = loc
    obj.data.materials.append(mat)
    if smooth and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def ellipsoid(name, parent, loc, scale, mat, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, parent, loc, mat)


def mesh(name, parent, vertices, faces, mat, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    SCENE.collection.objects.link(obj)
    finish(obj, name, parent, (0, 0, 0), mat)
    if bevel:
        mod = obj.modifiers.new('Forged rounded edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        norm = obj.modifiers.new('Weighted plate normals', 'WEIGHTED_NORMAL')
        norm.keep_sharp = True
    return obj


def ring_shape(name, parent, sections, mat, n=20):
    # z, front/back radius, lateral radius, forward offset.
    verts = []
    for z, rx, ry, x in sections:
        verts += [(x + rx * math.cos(i * math.tau / n), ry * math.sin(i * math.tau / n), z) for i in range(n)]
    faces = []
    for j in range(len(sections) - 1):
        for i in range(n):
            a = j * n + i
            b = j * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    faces += [tuple(range(n - 1, -1, -1)), tuple((len(sections) - 1) * n + i for i in range(n))]
    return mesh(name, parent, verts, faces, mat, .008)


def tube(name, parent, points, radius, mat):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 2
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new('POLY')
    spline.points.add(len(points) - 1)
    for p, xyz in zip(spline.points, points):
        p.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, data)
    SCENE.collection.objects.link(obj)
    finish(obj, name, parent, (0, 0, 0), mat)
    return obj


def segment(name, parent, a, b, radius_a, radius_b, mat, n=12):
    d = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=radius_a, radius2=radius_b, depth=d.length)
    obj = bpy.context.object
    obj.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return finish(obj, name, parent, (Vector(a) + Vector(b)) / 2, mat)


ROOT = pivot('Leon')
HIPS = pivot('Pelvis', ROOT, (0, 0, 1.03))
TORSO = pivot('Spine', HIPS, (0, 0, .07))
ring_shape('Quilted body under armor', TORSO, [(-.12, .16, .19, 0), (.1, .17, .19, 0), (.4, .21, .275, 0), (.55, .16, .21, 0)], MAIL)
ring_shape('Sculpted breastplate', TORSO, [(.08, .17, .18, .025), (.23, .23, .23, .025), (.43, .235, .275, .015), (.53, .13, .205, 0)], STEEL)
for z, rx, ry in [(.065, .184, .2), (.14, .191, .21), (.205, .205, .22)]:
    ring_shape('Overlapping articulated fauld', TORSO, [(z-.035,rx,ry,0), (z+.025,rx-.01,ry-.01,0)], EDGE)
    tube('Fauld gold edge', TORSO, [(rx*math.cos(i*math.tau/48), ry*math.sin(i*math.tau/48), z-.035) for i in range(49)], .006, GOLD)
# Raised center ridge and sweeping chest ornament.
tube('Breastplate center ridge', TORSO, [(.205, 0, .19), (.265, 0, .34), (.22, 0, .48)], .012, GOLD)
for side in [-1, 1]:
    tube('Breastplate gold flourish', TORSO, [(.235 - .03*t, side*(.02+.21*t), .46-.14*math.sin(t*math.pi/2)) for t in [i/24 for i in range(25)]], .009, GOLD_HI)
    for j in range(3):
        tube('Engraved scroll', TORSO, [(.244, side*(.045+j*.048+.02*math.cos(t)), .38-j*.026+.035*math.sin(t)) for t in [i*math.tau/30 for i in range(31)]], .0037, GOLD)
# Leather belt and buckle.
ring_shape('Leather waist belt', HIPS, [(-.035,.181,.204,0),(.04,.184,.205,0)], LEATHER)
ellipsoid('Lion belt buckle', HIPS, (.192, 0, .01), (.025,.055,.046), GOLD_HI)
for side in [-1,1]:
    for j in range(3):
        ellipsoid('Belt rivet', HIPS, (.177, side*(.08+j*.04), .012), (.011,.009,.009), GOLD)
# Front split red tabard, metal hanging tassets.
for side in [-1,1]:
    tab = mesh('Split crimson tabard', HIPS,
               [(.14,side*.015,-.04),(.14,side*.15,-.04),(.17,side*.16,-.51),(.19,side*.025,-.57)], [(0,1,2,3)], CRIMSON)
    sol=tab.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=.008
    plate=ring_shape('Hip plate '+str(side), HIPS, [(-.07,.17,.105,.015),(-.19,.175,.11,.025),(-.31,.14,.095,.035)],STEEL,n=16)
    plate.location.y=side*.18
    tube('Tasset gold ridge',HIPS,[(.18,side*.18,-.1),(.196,side*.18,-.2),(.16,side*.18,-.3)],.009,GOLD)

NECK=pivot('Neck',TORSO,(0,0,.56))
ring_shape('Gorget',NECK,[(0,.105,.11,0),(.075,.097,.1,0)],EDGE)
HEAD=pivot('Head',NECK,(.015,0,.07))
ellipsoid('Head sculpt',HEAD,(.01,0,.12),(.12,.106,.16),SKIN,32,20)
ellipsoid('Angular jaw',HEAD,(.045,0,.045),(.096,.087,.073),SKIN)
for side in [-1,1]:
    ellipsoid('Cheek plane',HEAD,(.079,side*.067,.105),(.055,.045,.055),SKIN_HI)
    ellipsoid('Ear',HEAD,(-.012,side*.103,.12),(.028,.018,.047),SKIN)
    ellipsoid('Eye socket',HEAD,(.111,side*.048,.145),(.02,.027,.018),LEATHER)
    ellipsoid('Eye',HEAD,(.125,side*.048,.145),(.01,.014,.008),EYE)
    tube('Eyebrow',HEAD,[(.119,side*.025,.168),(.121,side*.054,.175),(.108,side*.075,.168)],.009,HAIR)
mesh('Nose bridge',HEAD,[(.109,-.018,.173),(.109,.018,.173),(.168,-.014,.103),(.168,.014,.103),(.135,0,.09)],[(0,1,3,2),(2,3,4),(0,2,4),(1,4,3)],SKIN_HI,.007)
tube('Mouth',HEAD,[(.126,-.035,.062),(.14,0,.058),(.126,.035,.062)],.0035,LEATHER)
ellipsoid('Short beard',HEAD,(.095,0,.032),(.046,.075,.033),HAIR)
ellipsoid('Hair cap',HEAD,(-.023,0,.211),(.119,.112,.105),HAIR)
# Flowing individually modeled swept-back hair locks.
for i in range(38):
    t=i/37*math.tau
    a=(.02+.082*math.cos(t), .085*math.sin(t), .244+.025*math.sin(t*3))
    b=(-.12-random.random()*.045, .11*math.sin(t), .205-random.random()*.08)
    segment('Swept hair lock',HEAD,b,a,.004,.022,HAIR)

LEGS={}
ARMS={}
for side in [-1,1]:
    thigh=pivot('Thigh'+str(side),HIPS,(0,side*.125,-.08))
    ring_shape('Thigh leather',thigh,[(0,.1,.105,0),(-.31,.087,.09,0),(-.43,.075,.08,0)],LEATHER)
    ring_shape('Cuisses plate',thigh,[(-.04,.115,.108,.015),(-.2,.104,.1,.025),(-.36,.08,.089,.02)],STEEL)
    tube('Thigh plate ridge',thigh,[(.126,0,-.06),(.12,0,-.22),(.092,0,-.36)],.008,GOLD)
    knee=pivot('Knee'+str(side),thigh,(0,0,-.43))
    ellipsoid('Knee armor',knee,(.04,0,0),(.116,.105,.095),EDGE)
    ellipsoid('Knee lion boss',knee,(.142,0,.015),(.015,.039,.041),GOLD)
    ring_shape('Shin greave',knee,[(-.065,.085,.09,0),(-.22,.081,.083,0),(-.38,.062,.075,0)],STEEL)
    tube('Greave gold ridge',knee,[(.09,0,-.075),(.095,0,-.22),(.073,0,-.38)],.009,GOLD_HI)
    ankle=pivot('Ankle'+str(side),knee,(0,0,-.4))
    ellipsoid('Leather boot',ankle,(.067,0,-.024),(.163,.081,.073),LEATHER)
    for j in range(4):
        ring_shape('Articulated sabaton',ankle,[(-.055,.06,.083, .035+j*.036),(.01,.064,.08,.035+j*.036)],STEEL,n=12)
    LEGS[side]=(thigh,knee,ankle)
    shoulder=pivot('Shoulder'+str(side),TORSO,(0,side*.3,.44))
    ring_shape('Upper arm mail',shoulder,[(0,.078,.08,0),(-.28,.069,.07,0)],MAIL)
    ellipsoid('Layered pauldron',shoulder,(0,side*.022,-.015),(.169,.168,.14),STEEL)
    for j in range(3):
        ring_shape('Shoulder lames',shoulder,[(-.06-j*.065,.135-j*.015,.145-j*.014,0),(-.12-j*.065,.125-j*.015,.135-j*.014,0)],EDGE,n=16)
    # Lion face relief on outside shoulder, with sculpted muzzle and mane curls.
    sy=side*.157
    ellipsoid('Lion mane medallion',shoulder,(.015,sy,-.03),(.105,.018,.11),GOLD)
    ellipsoid('Lion brow',shoulder,(.045,sy+side*.017,-.009),(.067,.025,.05),GOLD_HI)
    ellipsoid('Lion muzzle',shoulder,(.065,sy+side*.028,-.059),(.042,.025,.028),GOLD_HI)
    for i in range(12):
        t=i*math.tau/12
        ellipsoid('Lion mane curl',shoulder,(.015+.089*math.cos(t),sy+side*.008,-.03+.09*math.sin(t)),(.025,.018,.022),GOLD)
    elbow=pivot('Elbow'+str(side),shoulder,(0,0,-.3))
    ellipsoid('Elbow couter',elbow,(-.01,0,0),(.095,.09,.09),EDGE)
    ring_shape('Vambrace',elbow,[(-.035,.079,.078,0),(-.18,.073,.072,0),(-.29,.058,.063,0)],STEEL)
    tube('Vambrace gold flute',elbow,[(.082,0,-.04),(.079,0,-.19),(.065,0,-.28)],.008,GOLD_HI)
    hand=pivot('Hand'+str(side),elbow,(0,0,-.31))
    ellipsoid('Leather gauntlet palm',hand,(0,0,-.045),(.06,.056,.078),LEATHER)
    ellipsoid('Gauntlet plate',hand,(.043,0,-.043),(.029,.061,.06),STEEL)
    for j in range(4):
        segment('Armored finger',hand,(.023,-.038+j*.025,-.08),(.043,-.038+j*.025,-.123),.011,.013,STEEL,n=8)
    ARMS[side]=(shoulder,elbow,hand)

# Dense fur collar: tapered clumps rather than a flat collar texture.
for i in range(88):
    t=i*math.tau/88
    x=-.025+.18*math.cos(t)
    y=.24*math.sin(t)
    z=.49+.035*math.cos(t*4)
    a=(x,y,z+.07)
    b=(x-.045,y*1.18,z-.08-random.random()*.035)
    segment('Fur tuft',TORSO,b,a,.004,.028,FUR_HI if i%3 else FUR,n=7)

CAPE=pivot('Cape',TORSO,(-.16,0,.46))
cape_vertices=[]
cape_faces=[]
NX,NY=14,20
for j in range(NY+1):
    v=j/NY
    for i in range(NX+1):
        u=i/NX
        width=.21+.19*math.sin(v*math.pi*.7)
        x=-.025-.2*v-.045*math.sin(u*math.pi*7)*(0.15+v)
        y=(u-.5)*2*width
        z=-1.12*v
        if j==NY:
            z+=.06*(i%3)+.025*math.sin(i*3.7)
        cape_vertices.append((x,y,z))
for j in range(NY):
    for i in range(NX):
        a=j*(NX+1)+i
        # Ragged holes at the hem are actual gaps in the mesh.
        if j>NY-3 and (i+j*3)%11==0:
            continue
        cape_faces.append((a,a+1,a+NX+2,a+NX+1))
CLOTH=mesh('Torn crimson cape',CAPE,cape_vertices,cape_faces,CRIMSON)
CLOTH.data.materials.append(LINING)
sol=CLOTH.modifiers.new('Fabric thickness','SOLIDIFY');sol.thickness=.008;sol.material_offset=1
sub=CLOTH.modifiers.new('Soft cloth folds','SUBSURF');sub.levels=1
for i in [0,NX]:
    tube('Cape narrow gold hem',CAPE,[cape_vertices[j*(NX+1)+i] for j in range(NY+1)],.0055,GOLD)

SWORD=pivot('Greatsword',ARMS[-1][2],(0,0,-.085))
# Sword runs down its local -Z; grip extends upward so both hands can close on it.
segment('Wrapped leather grip',SWORD,(0,0,-.015),(0,0,.25),.028,.026,LEATHER,n=12)
for j in range(10):
    tube('Grip winding',SWORD,[(.03*math.cos(t),.03*math.sin(t),j*.024+.013) for t in [i*math.tau/16 for i in range(17)]],.0035,GOLD)
ellipsoid('Gold pommel',SWORD,(0,0,.28),(.045,.043,.045),GOLD)
guard=[(-.02,-.22,.035),(.015,-.12,.055),(.025,0,.035),(.015,.12,.055),(-.02,.22,.035)]
tube('Swept crossguard',SWORD,guard,.026,GOLD_HI)
for side in [-1,1]:
    ellipsoid('Guard lion finial',SWORD,(-.015,side*.205,.035),(.034,.035,.04),GOLD)
verts=[(0,-.068,-.04),(.014,0,-.04),(0,.068,-.04),(-.014,0,-.04),
       (0,-.059,-1.19),(.009,0,-1.19),(0,.059,-1.19),(-.009,0,-1.19), (0,0,-1.43)]
faces=[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8)]
mesh('Forged greatsword blade',SWORD,verts,faces,BLADE,.002)
tube('Blade dark central fuller',SWORD,[(.0145,0,-.1),(.013,0,-1.16)],.007,FULLER)

BASE={name:(obj.location.copy(),obj.rotation_euler.copy()) for name,obj in JOINTS.items()}


def reset_pose():
    for name,obj in JOINTS.items():
        obj.location=BASE[name][0]
        obj.rotation_euler=BASE[name][1]


def radians(v):
    return math.radians(v)


def pose_idle(k):
    reset_pose()
    p=k*math.tau
    HIPS.location.z=1.03+.008*math.sin(p)
    TORSO.rotation_euler.y=radians(2+math.sin(p)*.6)
    for side in [-1,1]:
        LEGS[side][0].rotation_euler.y=radians(-4*side)
        LEGS[side][1].rotation_euler.y=radians(-5)
        ARMS[side][0].rotation_euler.y=radians(-8 if side==-1 else -4)
        ARMS[side][1].rotation_euler.y=radians(-17)
    SWORD.rotation_euler.y=radians(-64)
    CAPE.rotation_euler.y=radians(4+math.sin(p)*1.5)


def pose_run(k):
    reset_pose()
    p=k*math.tau
    HIPS.location.z=.96+.018*math.cos(p*2)
    TORSO.rotation_euler.y=radians(10)
    TORSO.rotation_euler.z=radians(4*math.sin(p))
    for side in [-1,1]:
        phase=(k+(0 if side==-1 else .5))%1
        ph=phase*math.tau
        thigh,knee,ankle=LEGS[side]
        # Two-link leg IK: ground contact then a raised return arc. Positive
        # knee flex folds the heel BACK, rather than kicking the shin forward.
        if phase<.5:
            foot_x=.29-1.16*phase
            foot_z=.075
        else:
            u=(phase-.5)*2
            foot_x=-.29+.58*smooth(u)
            foot_z=.075+.21*math.sin(math.pi*u)
        down=HIPS.location.z-.08-foot_z
        distance=min(.829,math.hypot(foot_x,down))
        flex=math.pi-math.acos(max(-1,min(1,(.43**2+.4**2-distance**2)/(2*.43*.4))))
        upper=math.atan2(-foot_x,down)-math.atan2(.4*math.sin(flex),.43+.4*math.cos(flex))
        thigh.rotation_euler.y=upper
        knee.rotation_euler.y=flex
        ankle.rotation_euler.y=-(upper+flex)
        shoulder,elbow,hand=ARMS[side]
        shoulder.rotation_euler.y=radians(18*math.sin(ph))
        elbow.rotation_euler.y=radians(-35-8*math.cos(ph))
    SWORD.rotation_euler.y=radians(56)
    CAPE.rotation_euler.y=radians(35+6*math.sin(p*2+.5))
    CAPE.rotation_euler.x=radians(4*math.sin(p))


def smooth(t):
    t=max(0,min(1,t))
    return t*t*(3-2*t)


def pose_attack(k):
    reset_pose()
    # Three timing segments. Actual damage stays in player.gd.
    if k<.3:
        u=smooth(k/.3); angle=-25-122*u; twist=-14*u
    elif k<.53:
        u=smooth((k-.3)/.23); angle=-147+225*u; twist=-14+35*u
    else:
        u=smooth((k-.53)/.47); angle=78-103*u; twist=21*(1-u)
    HIPS.location.z=.99
    TORSO.rotation_euler.y=radians(twist)
    TORSO.rotation_euler.z=radians(-5*math.sin(k*math.pi))
    for side in [-1,1]:
        LEGS[side][0].rotation_euler.y=radians(-20*side)
        LEGS[side][1].rotation_euler.y=radians(-15 if side==1 else -6)
        ARMS[side][0].rotation_euler.y=radians(angle)
        ARMS[side][1].rotation_euler.y=radians(-30)
    # The off hand closes toward the main grip instead of a separate idle arm.
    ARMS[1][0].rotation_euler.x=radians(-40)
    ARMS[-1][0].rotation_euler.x=radians(8)
    SWORD.rotation_euler.y=radians(-15)
    CAPE.rotation_euler.y=radians(12+17*math.sin(k*math.pi))
    CAPE.rotation_euler.x=radians(8*math.sin(k*math.tau))


POSES={'idle':pose_idle,'run':pose_run,'attack':pose_attack}

# Soft three-point studio lighting; no painted highlights in the texture.
world=bpy.data.worlds.new('Studio world');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.15,.2,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
SCENE.world=world
for name,loc,power,size,color in [('Warm key',(3,-4,6),1100,4,(1,.87,.72)),('Cool fill',(1,4,3),850,3,(.64,.77,1)),('Cape rim',(-3,1,5),1400,3,(1,.65,.4))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);SCENE.collection.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector((0,0,1.1))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Sprite orthographic camera');camera_data.type='ORTHO';camera_data.ortho_scale=3.8
camera=bpy.data.objects.new('Sprite camera',camera_data);SCENE.collection.objects.link(camera)
target=Vector((0,0,1.63));camera.location=target+Vector((4,-8,2.8))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();SCENE.camera=camera
SCENE.render.engine='CYCLES';SCENE.cycles.device='CPU';SCENE.cycles.samples=24
SCENE.cycles.use_denoising=True
SCENE.render.threads_mode='FIXED';SCENE.render.threads=8
SCENE.render.film_transparent=True
SCENE.render.image_settings.file_format='PNG';SCENE.render.image_settings.color_mode='RGBA'
SCENE.render.resolution_x=SCENE.render.resolution_y=384;SCENE.render.resolution_percentage=100
SCENE.view_settings.view_transform='AgX'


def render(path):
    bpy.context.view_layer.update()
    SCENE.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


if PREVIEW:
    pose_idle(.1)
    SCENE.render.resolution_x=SCENE.render.resolution_y=768
    SCENE.cycles.samples=48
    camera_data.ortho_scale=2.9
    target=Vector((0,0,1.15));camera.location=target+Vector((4,-8,2.2))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    render(OUT/'knight-studio.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'leon.blend'))
    print('KNIGHT PREVIEW OK',flush=True)
    sys.exit(0)

# Bake joint transforms into named NLA clips for the exported real 3D asset.
SCENE.render.fps=30
for anim,fn in POSES.items():
    actions={}
    for name,obj in JOINTS.items():
        obj.animation_data_create()
        action=bpy.data.actions.new(anim+'_'+name)
        obj.animation_data.action=action
        actions[name]=action
    for i in range(25):
        fn(i/24 if anim=='attack' else i/24)
        for obj in JOINTS.values():
            obj.keyframe_insert(data_path='location',frame=i+1)
            obj.keyframe_insert(data_path='rotation_euler',frame=i+1)
    for name,obj in JOINTS.items():
        obj.animation_data.action=None
        track=obj.animation_data.nla_tracks.new();track.name=anim
        track.strips.new(anim,1,actions[name]);track.mute=True
pose_idle(0)
SCENE.frame_start=1;SCENE.frame_end=25
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'leon.blend'))
# Curves are converted only in the GLB export copy; the blend keeps editable curves.
for obj in list(SCENE.objects):
    if obj.type=='CURVE':
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
for obj in JOINTS.values():
    for track in obj.animation_data.nla_tracks:
        track.mute=False
bpy.ops.export_scene.gltf(filepath=str(OUT/'leon.glb'),export_format='GLB',export_animations=True,
                         export_nla_strips=True,export_force_sampling=True,export_yup=True,
                         export_cameras=False,export_lights=False)
for obj in JOINTS.values():
    for track in obj.animation_data.nla_tracks:
        track.mute=True

for n in [8,10]:
    folder=OUT/str(n);folder.mkdir(exist_ok=True)
    for anim in ['run','attack']:
        for i in range(n):
            POSES[anim](i/(n-1) if anim=='attack' else i/n)
            render(folder/f'{anim}_{i:02}.png')
for i in range(4):
    pose_idle(i/4);render(OUT/f'idle_{i:02}.png')
(OUT/'provenance.json').write_text(json.dumps({'model':'Leon','renderer':bpy.app.version_string,
    'geometry':'Modeled meshes and joint pivots, no billboard or image-plane characters',
    'reference':'Original Leon sprite and approved 3D look-development image',
    'variants':[8,10],'animations':['idle','run','attack'],'runtime_frame_size':384},indent=2)+'\n')
print('KNIGHT 3D RENDERS OK: 4 idle + 8/10 run and attack',flush=True)
