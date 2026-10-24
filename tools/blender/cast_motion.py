"""Actual articulated 3D motion bases and transparent pose renders for 17 actors.
Blender CLI: blender -b --python tools/blender/cast_motion.py -- /absolute/raw [ids]
Final painted sprites are a separate image-generation stage, NOT these meshes.
"""
import bpy,sys,json,math,random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:];OUT=Path(args[0]);OUT.mkdir(parents=True,exist_ok=True)
SPECS=json.loads((ROOT/'tools/art_sources/cast/specs.json').read_text())

def mat(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;return m

def joint(name,parent=None,loc=(0,0,0)):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;o.rotation_mode='XYZ';J[name]=o;return o

def ball(name,parent,loc,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8);o=bpy.context.object;o.name=name;o.parent=parent;o.location=loc;o.scale=scale;o.data.materials.append(material);return o

def box(name,parent,loc,scale,material):
 bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.name=name;o.parent=parent;o.location=loc;o.scale=scale;o.data.materials.append(material);return o

def rod(name,parent,start,end,radius,material):
 a=Vector(start);b=Vector(end);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=radius,radius2=radius*.8,depth=d.length)
 o=bpy.context.object;o.name=name;o.parent=parent;o.location=(a+b)/2;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material);return o

def surface(name,parent,verts,faces,material):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(material);return o

def build(s):
 global J
 J={};root=joint(s['id']);hip=joint('Pelvis',root,(0,0,1.15));spine=joint('Spine',hip,(0,0,.1));legs={};arms={}
 color=(.12,.06,.09) if s['id']!='ranger' else (.13,.22,.08)
 if s['id'] in ['mage','wraith']:color=(.17,.24,.48)
 if s['id']=='void_lord':color=(.22,.06,.38)
 cloth=mat('Cloth',color);steel=mat('Steel',(.45,.49,.55),.8);gold=mat('Gold',(.55,.35,.1),.7);bone=mat('Bone',(.66,.61,.47));skin=mat('Skin',(.48,.32,.25));dark=mat('Dark iron',(.07,.07,.09),.7)
 armor=steel if s['group']=='heroes' else dark
 width=.25 if s['family']!='brute' else .39
 bodymat=bone if s['family']=='skeleton' else (skin if s['family'] in ['ghoul','brute'] else armor)
 if s['family']=='bat':
  ball('Bat body',hip,(0,0,.25),(.18,.13,.23),dark);ball('Bat head',hip,(.08,0,.43),(.14,.12,.13),dark)
  for side in [-1,1]:
   wing=joint('Wing'+str(side),hip,(0,side*.1,.25))
   verts=[(0,0,0),(-.12,side*.82,.22),(-.32,side*.72,-.18),(-.12,side*.4,-.09),(-.2,side*.12,-.2)]
   surface('Membrane',wing,verts,[(0,1,2,3,4)],cloth)
   for v in verts[1:4]:rod('Wing finger',wing,(0,0,0),v,.014,bone)
  return root,hip,spine,legs,arms,None,None
 ball('Torso',spine,(0,0,.2),(.17,width,.3),bodymat);ball('Pelvis mesh',hip,(0,0,-.015),(.15,width*.7,.12),cloth)
 head=joint('Head',spine,(0,0,.57));ball('Head mesh',head,(0,0,0),(.105,.105,.135),bone if s['family']=='skeleton' else skin)
 if s['family'] in ['armor','leather']:
  for side in [-1,1]:ball('Pauldron',spine,(0,side*(width+.035),.41),(.15,.13,.13),gold if s['id']=='knight' else armor)
 if s['family'] in ['robe','ghost'] or s['id']=='necro':
  bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.34,radius2=.14,depth=.9);robe=bpy.context.object;robe.name='Robe';robe.parent=hip;robe.location=(0,0,-.32);robe.data.materials.append(cloth)
 if s['family']!='ghost':
  for side in [-1,1]:
   thigh=joint('Thigh'+str(side),hip,(0,side*.13,-.075));rod('Thigh mesh',thigh,(0,0,0),(0,0,-.52),.072,bodymat)
   knee=joint('Knee'+str(side),thigh,(0,0,-.52));rod('Calf mesh',knee,(0,0,0),(0,0,-.48),.055,bodymat)
   ankle=joint('Ankle'+str(side),knee,(0,0,-.48));ball('Boot',ankle,(.045,0,-.045),(.12,.065,.07),dark);legs[side]=(thigh,knee,ankle)
 for side in [-1,1]:
  shoulder=joint('Shoulder'+str(side),spine,(0,side*(width+.02),.4));rod('Upper arm',shoulder,(0,0,0),(0,0,-.28),.065,bodymat)
  elbow=joint('Elbow'+str(side),shoulder,(0,0,-.28));rod('Forearm',elbow,(0,0,0),(0,0,-.26),.052,bodymat)
  hand=joint('Hand'+str(side),elbow,(0,0,-.26));ball('Hand mesh',hand,(0,0,-.025),(.06,.052,.075),bone if s['family']=='skeleton' else skin);arms[side]=(shoulder,elbow,hand)
 cape=joint('Cape',spine,(-.16,0,.45));surface('Cape cloth',cape,[(0,-.2,0),(0,.2,0),(-.22,.31,-1.15),(-.26,-.29,-1.15)],[(0,1,2,3)],cloth)
 weapon=joint('Weapon',arms[-1][2])
 if s['weapon'] in ['sword','daggers','shield']:
  length=.8 if s['weapon']!='daggers' else .37
  box('Blade',weapon,(0,0,-length/2),(.045,.025,length),steel);box('Guard',weapon,(0,0,.04),(.06,.22,.045),gold)
  if s['weapon']=='daggers':box('Offhand blade',arms[1][2],(0,0,-.19),(.045,.025,.38),steel)
  if s['weapon']=='shield':box('Tower shield',arms[1][2],(.08,0,-.07),(.09,.4,.75),dark)
 elif s['weapon']=='bow':
  pts=[(.2*math.sin(t*math.pi),0,.5-t) for t in [i/10 for i in range(11)]]
  for a,b in zip(pts,pts[1:]):rod('Bow limb',weapon,a,b,.025,gold)
  rod('Bowstring',weapon,pts[0],pts[-1],.005,bone)
 elif s['weapon']=='staff':
  rod('Staff',weapon,(0,0,-.65),(0,0,.85),.03,gold);ball('Orb',weapon,(0,0,.95),(.12,.12,.12),cloth)
 elif s['weapon']=='club':
  rod('Club handle',weapon,(0,0,-.7),(0,0,.15),.045,dark);ball('Club head',weapon,(0,0,-.7),(.18,.18,.25),dark)
 elif s['weapon']=='bomb':
  for side in [-1,1]:rod('Explosive cylinder',spine,(-.23,side*.12,-.05),(-.23,side*.12,.6),.105,dark)
 return root,hip,spine,legs,arms,weapon,cape

def pose(s,rig,anim,p):
 root,hip,spine,legs,arms,weapon,cape=rig
 for n,o in J.items():o.location=REST[n][0];o.rotation_euler=REST[n][1]
 phase=p*math.tau
 if s['family']=='bat':
  hip.location.z=1.3+.06*math.sin(phase)
  for side in [-1,1]:J['Wing'+str(side)].rotation_euler.x=side*.7*math.sin(phase)
  if anim=='attack':hip.rotation_euler.y=.3*math.sin(math.pi*p)
  return
 hip.location.z+=.012*math.sin(phase);spine.rotation_euler.y=.02*math.sin(phase)
 if anim=='run' and legs:
  hip.location.z-=.025;spine.rotation_euler.y=.10
  for side in [-1,1]:
   q=(p+(0 if side<0 else .5))%1
   foot_x=.29-1.16*q if q<.5 else -.29+.58*(q-.5)*2
   lift=0 if q<.5 else .24*math.sin((q-.5)*2*math.pi)
   down=.96-lift;dist=min(.999,math.hypot(down,foot_x));flex=math.pi-math.acos(max(-1,min(1,(.52**2+.48**2-dist**2)/(2*.52*.48))))
   upper=math.atan2(-foot_x,down)-math.atan2(.48*math.sin(flex),.52+.48*math.cos(flex))
   thigh,knee,ankle=legs[side];thigh.rotation_euler.y=upper;knee.rotation_euler.y=flex;ankle.rotation_euler.y=-upper-flex
   arms[side][0].rotation_euler.y=.3*math.sin(phase);arms[side][1].rotation_euler.y=-.4
  cape.rotation_euler.y=.3+.08*math.sin(phase*2)
 elif anim=='attack':
  k=math.sin(math.pi*p);spine.rotation_euler.y=.15*k
  if s['weapon']=='bow':arms[-1][0].rotation_euler.y=-1.1;arms[1][0].rotation_euler.y=-1;arms[1][1].rotation_euler.y=-1.3*k
  elif s['weapon']=='staff':arms[1][0].rotation_euler.y=-1.3*k
  else:
   for side in [-1,1]:arms[side][0].rotation_euler.y=-.25-1.1*k;arms[side][1].rotation_euler.y=-.5
   weapon.rotation_euler.y=-.5+.8*p
 if s['family']=='ghost':hip.location.z+=.05*math.sin(phase);cape.rotation_euler.y=.1*math.sin(phase)

for s in SPECS:
 if len(args)>1 and s['id'] not in args[1:]:continue
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 rig=build(s);REST={n:(o.location.copy(),o.rotation_euler.copy()) for n,o in J.items()}
 scene=bpy.context.scene;scene.render.fps=30
 for anim,count in [('idle',36),('run',24),('attack',30)]:
  actions={}
  for n,o in J.items():o.animation_data_create();a=bpy.data.actions.new(anim+'_'+n);o.animation_data.action=a;actions[n]=a
  for i in range(count+1):
   pose(s,rig,anim,i/count)
   for o in J.values():o.keyframe_insert('location',frame=i+1);o.keyframe_insert('rotation_euler',frame=i+1)
  for n,o in J.items():
   o.animation_data.action=None;t=o.animation_data.nla_tracks.new();t.name=anim;t.strips.new(anim,1,actions[n]);t.mute=True
 folder=ROOT/'assets/models/cast'/s['group'];folder.mkdir(parents=True,exist_ok=True)
 for o in J.values():
  for t in o.animation_data.nla_tracks:t.mute=False
 bpy.ops.export_scene.gltf(filepath=str(folder/(s['id']+'.glb')),export_format='GLB',export_animations=True,export_nla_strips=True,export_cameras=False,export_lights=False)
 for o in J.values():
  for t in o.animation_data.nla_tracks:t.mute=True
 scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=320;scene.render.resolution_y=320;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
 scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
 cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);scene.collection.objects.link(cam);target=Vector((0,0,1.15));cam.location=target+Vector((4,-8,2.2));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=3.1;scene.camera=cam
 dest=OUT/s['id'];dest.mkdir(exist_ok=True)
 for n in [8,10]:
  for anim,count in [('idle',n//2),('run',n),('attack',n)]:
   for i in range(count):
    pose(s,rig,anim,i/count if anim!='attack' else i/(count-1));scene.render.filepath=str(dest/f'{n}_{anim}_{i:02}.png');bpy.ops.render.render(write_still=True)
 print('CAST 3D OK:',s['id'],flush=True)
