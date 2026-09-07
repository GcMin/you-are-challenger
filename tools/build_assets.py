"""Rebuild only derived assets; original OBJ/FBX/UAL files stay untouched.
Run with Blender 5.2 --background --python tools/build_assets.py.
The OBJ consists of rigid low-poly body sections: fit each to the UAL rest bones.
"""
import bpy, bmesh, pathlib, math, json
from mathutils import Vector, Matrix
root=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.name='ChallengerRig'
actions={a.name:a for a in bpy.data.actions}
for o in list(bpy.context.scene.objects):
    if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
before=set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(root/'Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb'))
for a in set(bpy.data.actions)-before:actions[a.name]=a
for o in list(bpy.context.scene.objects):
    if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data_clear()
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.ops.wm.obj_import(filepath=str(root/'LowPolyHuman2.obj'))
human=bpy.context.selected_objects[0]
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for v in human.data.vertices:
    v.co=(v.co-Vector((0,0,-1.469615)))*(1.82/3.181982)
    v.co.y=-v.co.y # OBJ faces +Y; UAL faces -Y in Blender.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
parts=list(bpy.context.selected_objects)
def mat(name,color,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.65
    return m
armor=mat('Armor',(.12,.32,.36),.25);joint=mat('Joint',(.12,.17,.19));face=mat('Face',(.58,.65,.62),.15)
gloves=mat('Gloves',(.55,.36,.19))
def fit(v,src_head,src_tail,bone):
    sh=Vector(src_head); st=Vector(src_tail); b=rig.data.bones[bone]
    rot=(st-sh).normalized().rotation_difference((b.tail_local-b.head_local).normalized())
    # Preserve width, map longitudinal length onto the imported bone.
    axis=(st-sh).normalized();offset=v-sh;along=axis*offset.dot(axis)
    return b.head_local+rot@(offset-along+along*((b.tail_local-b.head_local).length/(st-sh).length))
for o in parts:
    vs=[v.co for v in o.data.vertices];c=sum(vs,Vector())/len(vs);x,z=abs(c.x),c.z;side='l' if c.x>0 else 'r';sign=1 if c.x>0 else -1
    bone='pelvis';material=armor;src=None
    if z>1.66:bone='Head';material=face
    elif z>1.55 and x<.1:bone='neck_01';material=joint
    elif x>.205 and z>.76:
        if z>1.38:bone='upperarm_'+side;src=((sign*.223,0,1.441),(sign*.252,0,1.185));material=armor
        elif z>1.24:bone='upperarm_'+side;src=((sign*.223,0,1.441),(sign*.252,0,1.185))
        elif z>1.16:bone='lowerarm_'+side;src=((sign*.252,0,1.185),(sign*.257,-.015,.933));material=joint
        elif z>.95:bone='lowerarm_'+side;src=((sign*.252,0,1.185),(sign*.257,-.015,.933))
        else:bone='hand_'+side;src=((sign*.257,-.015,.933),(sign*.257,-.025,.84));material=joint
    elif z>1.05:bone='spine_02'
    elif z>.8:bone='pelvis'
    elif z>.58:bone='thigh_'+side;src=((sign*.11,.01,.92),(sign*.128,.017,.504))
    elif z>.44:bone='calf_'+side;src=((sign*.128,.017,.504),(sign*.16,-.034,.09));material=joint
    elif z>.12:bone='calf_'+side;src=((sign*.128,.017,.504),(sign*.16,-.034,.09))
    else:bone='foot_'+side
    if src:
        for v in o.data.vertices:v.co=fit(v.co,*src,bone)
    elif bone=='Head':
        for v in o.data.vertices:v.co.z-=.055
    elif bone=='neck_01':
        for v in o.data.vertices:v.co.z-=.07
    elif bone.startswith('foot'):
        b=rig.data.bones[bone]
        for v in o.data.vertices:v.co.x+=b.head_local.x-sign*.16
    if bone.startswith('hand_'):
        material=gloves
        # Keep the supplied palm/thumb topology, but make a readable padded glove.
        pivot=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
        for v in o.data.vertices:v.co=pivot+(v.co-pivot)*1.25
    # Reflecting the source facing reverses winding. Recompute outside normals
    # after fitting each closed body segment, before exporting to Godot.
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    o.data.materials.clear();o.data.materials.append(material)
    g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();human=bpy.context.object;human.name='LowPolyHuman2'
mod=human.modifiers.new('UAL Skeleton','ARMATURE');mod.object=rig;human.parent=rig
# Preserve the original weapon geometry, normalize to 1.65m and put the grip at origin.
bpy.ops.import_scene.fbx(filepath=str(root/'MeleeAssets/TwoHandedGreatsword.fbx'))
sword=next(o for o in bpy.context.selected_objects if o.type=='MESH');bpy.context.view_layer.objects.active=sword
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
coords=[v.co.copy() for v in sword.data.vertices];lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
scale=1.65/(hi.z-lo.z);center=(lo+hi)*.5;grip=lo.z+(hi.z-lo.z)*.19
for v in sword.data.vertices:v.co=Vector(((v.co.x-center.x)*scale,v.co.y*scale,(v.co.z-grip)*scale))
sword.name='TwoHandedGreatsword';sword.data.materials.clear();sword.data.materials.append(mat('Steel',(.63,.72,.76),.8))
bpy.ops.object.select_all(action='DESELECT');sword.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/weapons/greatsword.glb'),use_selection=True,export_animations=False)
hand=rig.data.bones['hand_r'];mount=hand.matrix_local@Matrix.Translation((0,.07,0))
for v in sword.data.vertices:v.co=mount@v.co
g=sword.vertex_groups.new(name='hand_r');g.add(list(range(len(sword.data.vertices))),1,'REPLACE');sword.parent=rig;sword.modifiers.new('Grip','ARMATURE').object=rig
# Solve BOTH arms around a reachable shared grip. A left-only IK on a one-handed
# source pose extends through the torso and still cannot reach the distant sword.
def source_pose(source, frame):
    rig.animation_data_create();rig.animation_data.action=actions[source]
    if actions[source].slots:rig.animation_data.action_slot=actions[source].slots[0]
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame));bpy.context.view_layer.update()
    return {b.name:b.matrix.copy() for b in rig.pose.bones}

def aim_bone(matrix, start, end):
    old_axis=matrix.to_3x3().col[1].normalized()
    rot=old_axis.rotation_difference((end-start).normalized())@matrix.to_quaternion()
    return Matrix.LocRotScale(start,rot,Vector((1,1,1)))

grip_errors=[]
def two_hands(pose, grip_height=-.14, grip_forward=.29, blade_direction=None):
    left_sh=pose['upperarm_l'].translation;right_sh=pose['upperarm_r'].translation
    center=(left_sh+right_sh)*.5
    side=(right_sh-left_sh).normalized()
    # Fixed forward in rig space keeps the grip in front while source torso twists.
    forward=Vector((0,-1,0))
    source_delta=pose['hand_r'].translation-center
    # Keep authored sword rotation, but bring its grip between the shoulders.
    wrist=center+forward*grip_forward+Vector((0,0,grip_height))+side*.06
    wrist+=Vector((source_delta.x,source_delta.y,0))*.12
    hand_r=pose['hand_r'].copy();hand_r.translation=wrist
    if blade_direction is not None:
        blade_axis=(hand_r.to_3x3()@Vector((0,0,1))).normalized()
        rotation=blade_axis.rotation_difference(Vector(blade_direction).normalized())@hand_r.to_quaternion()
        hand_r=Matrix.LocRotScale(wrist,rotation,Vector((1,1,1)))
    hand_l=hand_r.copy();hand_l.translation=hand_r@Vector((0,.02,-.15))
    # Whole grip can move toward the shoulders, but the two hand targets stay rigid.
    for _ in range(12):
        if (hand_r.translation-right_sh).length<.49 and (hand_l.translation-left_sh).length<.49:break
        shift=(center-(hand_r.translation+hand_l.translation)*.5)*.1
        hand_r.translation+=shift;hand_l.translation+=shift
    for suffix,desired in [('r',hand_r),('l',hand_l)]:
        upper='upperarm_'+suffix;lower='lowerarm_'+suffix;hand_name='hand_'+suffix
        shoulder=pose[upper].translation;target=desired.translation
        l1=rig.data.bones[upper].length;l2=rig.data.bones[lower].length
        delta=target-shoulder;d=delta.length;axis=delta.normalized()
        assert .04<d<l1+l2-.01,(suffix,d,l1+l2)
        along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along))
        outward=(right_sh-left_sh).normalized()*(1 if suffix=='r' else -1)
        pole=outward+Vector((0,0,-.35))
        pole=(pole-axis*pole.dot(axis)).normalized()
        elbow=shoulder+axis*along+pole*height
        old_hand=pose[hand_name].copy()
        pose[upper]=aim_bone(pose[upper],shoulder,elbow)
        pose[lower]=aim_bone(pose[lower],elbow,target)
        pose[hand_name]=desired
        for child in rig.data.bones[hand_name].children_recursive:
            pose[child.name]=desired@old_hand.inverted()@pose[child.name]
    grip_errors.append((hand_l.translation-(hand_r@Vector((0,.02,-.15)))).length)
    return pose

def blend_pose(a,b,t):
    result={}
    for key in a:
        al,ar,asc=a[key].decompose();bl,br,bsc=b[key].decompose()
        result[key]=Matrix.LocRotScale(al.lerp(bl,t),ar.slerp(br,t),asc.lerp(bsc,t))
    return result

def end_frame(source):return float(actions[source].frame_range[1])
idle_pose=two_hands(source_pose('Sword_Idle',0))
clip_poses={}
for name,source in {'idle':'Sword_Idle','run':'Jog_Fwd_Loop','hit':'Hit_Chest','death':'Death01'}.items():
    clip_poses[name]=[source_pose(source,f) for f in range(int(end_frame(source))+1)]
    if name in ['idle','run']:clip_poses[name]=[two_hands(p) for p in clip_poses[name]]
# Bake attack phases to the actual gameplay clock at 60 fps, with recovery included.
light=[]
for f in range(46):
    t=f/60
    src=9*t/.25 if t<=.25 else 9+10*(t-.25)/.12 if t<=.37 else 19+(end_frame('Sword_Attack')-19)*(t-.37)/.38
    pose=two_hands(source_pose('Sword_Attack',src))
    if t<.10:pose=blend_pose(idle_pose,pose,t/.10)
    if t>.60:pose=blend_pose(pose,idle_pose,(t-.60)/.15)
    light.append(pose)
clip_poses['light']=light
heavy=[]
for f in range(84):
    t=min(1.38,f/60)
    if t<=.6:pose=two_hands(source_pose('Sword_Regular_A',3*t/.6))
    elif t<=.78:pose=two_hands(source_pose('Sword_Regular_A',3+7*(t-.6)/.18))
    else:pose=two_hands(source_pose('Sword_Regular_A_Rec',end_frame('Sword_Regular_A_Rec')*(t-.78)/.6))
    if t<.16:pose=blend_pose(idle_pose,pose,t/.16)
    if t>1.15:pose=blend_pose(pose,idle_pose,min(1,(t-1.15)/.23))
    heavy.append(pose)
clip_poses['heavy']=heavy
# Split the roll before its stand-up, then finish with a full return to the sword stance.
roll_split=25.0
clip_poses['roll']=[source_pose('Roll',roll_split*f/33) for f in range(34)]
for f in range(5):clip_poses['roll'][f]=blend_pose(idle_pose,clip_poses['roll'][f],f/5)
recovery=[]
for f in range(16):
    t=f/15
    pose=source_pose('Roll',roll_split+(end_frame('Roll')-roll_split)*min(t/.65,1))
    if t>.4:pose=blend_pose(pose,idle_pose,(t-.4)/.6)
    recovery.append(pose)
clip_poses['recover']=recovery
# Boss-specific silhouettes built on the UAL stance, with both arms solved to the grip.
raised=two_hands(source_pose('Sword_Idle',0), .22, .15, (0,0,1))
slammed=two_hands(source_pose('Sword_Idle',0), -.25, .40, (0,-1,-.8))
guard=two_hands(source_pose('Sword_Idle',0), -.12, .22, (0,-1,.12))
thrust=two_hands(source_pose('Sword_Idle',0), -.12, .43, (0,-1,.05))
for name,ready,contact,start,end in [('boss_slam',raised,slammed,.6/1.38,.78/1.38),('boss_dash',guard,thrust,.3,.65)]:
    poses=[]
    for f in range(121):
        t=f/120
        if t<start:
            # Last third of windup holds the tell instead of swinging prematurely.
            pose=blend_pose(idle_pose,ready,min(1,t/(start*.65)))
        elif t<end:pose=blend_pose(ready,contact,(t-start)/(end-start))
        else:pose=blend_pose(contact,idle_pose,(t-end)/(1-end))
        poses.append(pose)
    clip_poses[name]=poses
baked=[]
rig.animation_data_create()
for name,poses in clip_poses.items():
    rig.animation_data.action=None
    new=bpy.data.actions.new(name);rig.animation_data.action=new
    for frame,pose in enumerate(poses):
        # Preserve original timing for locomotion/hit clips when scene fps becomes 60.
        keyframe=frame*2.5 if name in ['idle','run','hit','death'] else frame
        for b in rig.pose.bones:
            args={'matrix':pose[b.name], 'matrix_local':b.bone.matrix_local, 'invert':True}
            if b.parent:
                args['parent_matrix']=pose[b.parent.name]
                args['parent_matrix_local']=b.parent.bone.matrix_local
            b.matrix_basis=b.bone.convert_local_to_pose(**args)
            b.rotation_mode='QUATERNION'
            b.keyframe_insert('location',frame=keyframe);b.keyframe_insert('rotation_quaternion',frame=keyframe);b.keyframe_insert('scale',frame=keyframe)
    baked.append((name,new));print('CLIP',name,len(poses))
bpy.context.scene.render.fps=60
print('MAX_GRIP_ERROR_METRES',max(grip_errors))
hand_vertex_counts={}
for name in ['upperarm_l','lowerarm_l','hand_l','upperarm_r','lowerarm_r','hand_r']:
    index=human.vertex_groups[name].index
    hand_vertex_counts[name]=sum(any(g.group==index and g.weight>.5 for g in v.groups) for v in human.data.vertices)
    assert hand_vertex_counts[name]>=16,(name,hand_vertex_counts[name])
assert max(grip_errors)<.0001
(root/'docs/rig_validation.json').write_text(json.dumps({'weighted_vertices':hand_vertex_counts,'max_grip_error_m':max(grip_errors),'clips':list(clip_poses)},indent=2))
rig.animation_data.action=None
for name,act in baked:
    track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,act)
    strip.action_frame_start=act.frame_range[0];strip.action_frame_end=act.frame_range[1]
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,human,sword]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(root/'assets/characters/challenger.glb'),use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/source/challenger_source.blend'))
print('ASSETS_COMPLETE')
