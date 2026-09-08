"""Run with Blender 4.5: blender -b --python generate_world.py -- --root <project>.

All surface samples use world coordinates, so independently exported 100 m cells
share identical border positions and normals. Blender Z-up is mapped to Unity Y-up.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--render', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
root = Path(args.root).resolve()
asset_dir = root / 'Assets/Scenes/WorldPartitions/MeadowWorld'
source_dir = root / 'Tools/WorldPartition'
report_dir = root / 'Logs/WorldPartitionGeneration'
for folder in [asset_dir / 'Models', source_dir, report_dir]:
    folder.mkdir(parents=True, exist_ok=True)

SIZE, STEP, SEED = 100, 2.5, 41729
PALETTE = {
    'Meadow': (0.39, 0.58, 0.26, 1),
    'MeadowLight': (0.44, 0.62, 0.29, 1),
    'MeadowDark': (0.34, 0.52, 0.24, 1),
    'Bank': (0.64, 0.61, 0.39, 1),
    'Cliff': (0.48, 0.53, 0.47, 1),
    'Stone': (0.57, 0.61, 0.55, 1),
    'StoneLight': (0.70, 0.72, 0.61, 1),
    'Bark': (0.30, 0.23, 0.16, 1),
    'Leaves': (0.23, 0.43, 0.22, 1),
    'LeavesLight': (0.40, 0.57, 0.24, 1),
    'LeavesGold': (0.63, 0.65, 0.28, 1),
    'Grass': (0.52, 0.65, 0.28, 1),
    'Flowers': (0.91, 0.79, 0.48, 1),
    'Road': (0.69, 0.61, 0.41, 1),
    'Water': (0.17, 0.52, 0.54, 1),
    'Foam': (0.61, 0.80, 0.74, 1),
    'Timber': (0.46, 0.33, 0.21, 1),
    'TimberLight': (0.62, 0.46, 0.28, 1),
}

def river(z):
    return 60 + 35 * math.sin(z / 110) + 12 * math.sin(z / 48)

def road(x):
    return -30 + 16 * math.sin(x / 85)

def smooth(a):
    a = max(0, min(1, a))
    return a * a * (3 - 2 * a)

def height(x, z):
    hills = 12 + 3 * math.sin(x / 62) * math.cos(z / 79)
    for hx, hz, amplitude, radius in [(-205, 175, 46, 112), (260, 235, 58, 130),
                                      (-200, -190, 25, 115), (305, -145, 35, 90)]:
        hills += amplitude * math.exp(-((x - hx) ** 2 + (z - hz) ** 2) / radius ** 2)
    hills += 1.2 * math.sin(x / 19 + z / 35) * math.sin(z / 25)
    return 4.2 + (hills - 4.2) * smooth((abs(x - river(z)) - 6) / 22)

def normal(x, z):
    e = .05
    dx = (height(x + e, z) - height(x - e, z)) / (2 * e)
    dz = (height(x, z + e) - height(x, z - e)) / (2 * e)
    return Vector((-dx, -dz, 1)).normalized()

# This is a fresh background Blender process; do not operate on an interactive file.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version = 0
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
scene.name = 'Meadow World - 700m - 49 streaming cells'
materials = {}
for name, color in PALETTE.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(v ** 2.2 for v in color[:3]) + (1,)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Roughness'].default_value = .28 if name == 'Water' else .86
    materials[name] = mat

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1)
template = bpy.context.object
ico_vertices = [tuple(v.co) for v in template.data.vertices]
ico_faces = [tuple(p.vertices) for p in template.data.polygons]
bpy.data.objects.remove(template, do_unlink=True)

class Geometry:
    def __init__(self, name, cx, cz):
        self.name, self.cx, self.cz = name, cx, cz
        self.vertices, self.faces, self.indices, self.mat_names = [], [], [], []

    def add(self, verts, faces, material):
        if material not in self.mat_names:
            self.mat_names.append(material)
        offset = len(self.vertices)
        self.vertices.extend((x - self.cx * SIZE, z - self.cz * SIZE, h) for x, h, z in verts)
        self.faces.extend(tuple(offset + i for i in f) for f in faces)
        self.indices.extend([self.mat_names.index(material)] * len(faces))

    def box(self, x, h, z, sx, sy, sz, material):
        verts = [(x + dx * sx / 2, h + dy * sy / 2, z + dz * sz / 2)
                 for dx, dy, dz in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),
                                   (-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
        self.add(verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], material)

    def ellipsoid(self, x, h, z, sx, sy, sz, material, angle=0):
        c, s = math.cos(angle), math.sin(angle)
        verts = [(x + a * sx * c - b * sz * s, h + d * sy, z + a * sx * s + b * sz * c)
                 for a, b, d in ico_vertices]
        self.add(verts, ico_faces, material)

    def trunk(self, x, h, z, radius, length, material='Bark'):
        verts = [(x + math.cos(i * math.tau / 7) * radius * scale, h + y,
                  z + math.sin(i * math.tau / 7) * radius * scale)
                 for y, scale in [(0,1), (length,.58)] for i in range(7)]
        faces = [(i,(i+1)%7,(i+1)%7+7,i+7) for i in range(7)]
        faces += [tuple(range(6,-1,-1)), tuple(range(7,14))]
        self.add(verts, faces, material)

    def finish(self, collection, smooth_normals=False):
        if not self.faces:
            return None
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        obj.location = (self.cx * SIZE, self.cz * SIZE, 0)
        for name in self.mat_names:
            mesh.materials.append(materials[name])
        for poly, index in zip(mesh.polygons, self.indices):
            poly.material_index = index
            poly.use_smooth = smooth_normals
        if smooth_normals:
            mesh.normals_split_custom_set_from_vertices([
                normal(v[0] + self.cx * SIZE, v[1] + self.cz * SIZE) for v in self.vertices])
        return obj

def clipped(poly, cx, cz):
    # Clip world-space ribbon polygons to a cell; no duplicated geometry at borders.
    for axis, limit, sign in [(0,cx*SIZE,1),(0,(cx+1)*SIZE,-1),
                               (2,cz*SIZE,1),(2,(cz+1)*SIZE,-1)]:
        output = []
        for p, q in zip(poly, poly[1:] + poly[:1]):
            pin, qin = sign * (p[axis] - limit) >= -1e-7, sign * (q[axis] - limit) >= -1e-7
            if pin:
                output.append(p)
            if pin != qin:
                t = (limit - p[axis]) / (q[axis] - p[axis])
                output.append(tuple(p[j] + t * (q[j] - p[j]) for j in range(3)))
        poly = output
        if len(poly) < 3:
            return []
    return poly

def ribbon(geo, points, mat):
    poly = clipped(points, geo.cx, geo.cz)
    if poly:
        geo.add(poly, [tuple(range(len(poly)))], mat)

manifest = {'name':'MeadowWorld', 'seed':SEED, 'chunkSize':SIZE, 'minX':-3, 'maxX':3,
            'minZ':-3, 'maxZ':3, 'materials':[], 'chunks':[],
            'spawn':{'x':0,'y':height(0,0)+2,'z':0},
            'camera':{'x':-95,'y':88,'z':-130}, 'cameraTarget':{'x':40,'y':8,'z':40}}
for name, color in PALETTE.items():
    manifest['materials'].append({'name':name,'color':{'r':color[0],'g':color[1],'b':color[2],'a':1},
                                  'smoothness':.5 if name == 'Water' else .12})

all_objects, terrain_edges = [], {}
tree_count = 0
for cx in range(-3,4):
    for cz in range(-3,4):
        key = f'Chunk_X{cx}_Y0_Z{cz}'
        collection = bpy.data.collections.new(key)
        scene.collection.children.link(collection)
        rng = random.Random(SEED + (cx + 3) * 1009 + (cz + 3) * 9176)
        land = Geometry('Terrain', cx, cz)
        # Shared grid vertices are required for truly continuous interpolated normals.
        n = int(SIZE / STEP)
        land.vertices = [(i*STEP,j*STEP,height(cx*SIZE+i*STEP,cz*SIZE+j*STEP))
                         for j in range(n+1) for i in range(n+1)]
        land.mat_names = ['Meadow','MeadowLight','MeadowDark','Bank','Cliff']
        for j in range(n):
            for i in range(n):
                a = j*(n+1)+i
                x,z = cx*SIZE+(i+.5)*STEP,cz*SIZE+(j+.5)*STEP
                slope = normal(x,z).z
                patch = math.sin(x/21) + math.sin(z/27) * math.cos(x/33)
                material = 3 if abs(x-river(z)) < 16 else (4 if slope < .83 else (1 if patch>1.0 else (2 if patch < -1.0 else 0)))
                land.faces.extend([(a,a+1,a+n+1),(a+1,a+n+2,a+n+1)])
                land.indices.extend([material,material])
        terrain_edges[(cx,cz)] = land.vertices
        objs = [land.finish(collection, True)]
        water, foam, path = Geometry('Water',cx,cz), Geometry('RiverFoam',cx,cz), Geometry('Path',cx,cz)
        for zi in range(cz*40,(cz+1)*40):
            z0,z1 = zi*STEP,(zi+1)*STEP
            ribbon(water,[(river(z0)-15,6,z0),(river(z0)+15,6,z0),
                          (river(z1)+15,6,z1),(river(z1)-15,6,z1)], 'Water')
            if zi % 13 in (0,1,2):
                x0,x1 = river(z0)-3+3*math.sin(z0/9),river(z1)-3+3*math.sin(z1/9)
                ribbon(foam,[(x0,6.045,z0),(x0+.22,6.045,z0),(x1+.22,6.045,z1),(x1,6.045,z1)],'Foam')
        for xi in range(cx*40,(cx+1)*40):
            x0,x1 = xi*STEP,(xi+1)*STEP
            if abs((x0+x1)/2-river(road((x0+x1)/2))) < 23:
                continue
            verts = [(x0,height(x0,road(x0)-2)+.08,road(x0)-2),
                     (x1,height(x1,road(x1)-2)+.08,road(x1)-2),
                     (x1,height(x1,road(x1)+2)+.08,road(x1)+2),
                     (x0,height(x0,road(x0)+2)+.08,road(x0)+2)]
            ribbon(path, verts,'Road')
        for geo in [water,foam,path]:
            obj = geo.finish(collection)
            if obj: objs.append(obj)
        trunks, crowns, rocks, grass = [Geometry(name,cx,cz) for name in ['Trunks','Canopies','Rocks','GroundCover']]
        for _ in range(46):
            x,z = cx*SIZE+rng.uniform(8,92),cz*SIZE+rng.uniform(8,92)
            if abs(x-river(z)) < 29 or abs(z-road(x)) < 11 or normal(x,z).z < .88:
                continue
            if math.sin(x/39)*math.cos(z/51) < -.28 or rng.random() < .2:
                continue
            h = height(x,z)
            length,radius = rng.uniform(7,12),rng.uniform(2.8,4.3)
            trunks.trunk(x,h-.25,z,.42,length)
            for dx,dz,scale,up in [(0,0,1,1),(-1.3,.7,.82,.85),(1.1,-.6,.82,.8)]:
                crowns.ellipsoid(x+dx,h+length*up,z+dz,radius*scale,radius*.9,radius*scale,
                                 rng.choices(['Leaves','LeavesLight','LeavesGold'],[6,4,1])[0],rng.random()*math.tau)
            tree_count += 1
        for _ in range(12):
            x,z = cx*SIZE+rng.uniform(5,95),cz*SIZE+rng.uniform(5,95)
            if abs(x-river(z))<13 or abs(z-road(x))<6: continue
            scale = rng.uniform(.9,3.3)
            rocks.ellipsoid(x,height(x,z)+scale*.25,z,scale,scale*.65,scale*.8,
                            rng.choice(['Stone','StoneLight','Cliff']),rng.random()*math.tau)
        for _ in range(95):
            x,z = cx*SIZE+rng.uniform(1,99),cz*SIZE+rng.uniform(1,99)
            if abs(x-river(z))<24 or abs(z-road(x))<5: continue
            h = height(x,z)
            for _ in range(3):
                a = rng.random()*math.tau
                dx,dz = .26*math.cos(a),.26*math.sin(a)
                tip = rng.uniform(.4,.9)
                grass.add([(x-dx,h,z-dz),(x+dx,h,z+dz),(x+dx*.8,h+tip,z+dz*.8)],[(0,2,1)],'Grass')
            if rng.random()<.16:
                grass.ellipsoid(x,h+.6,z,.19,.15,.19,'Flowers')
        for geo in [trunks,crowns,rocks,grass]:
            obj = geo.finish(collection)
            if obj: objs.append(obj)
        # Curving timber bridge belongs to one cell, fully inside its bounds.
        if (cx,cz)==(0,-1):
            bridge = Geometry('Bridge',cx,cz)
            for i in range(36):
                x = 24+i*1.4
                deck = 10.4 + 1.8*math.sin(math.pi*i/35)
                bridge.box(x,deck,road(x),1.32,.34,6,'TimberLight' if i%4 else 'Timber')
                for side in [-1,1]:
                    bridge.box(x,deck+1.7,road(x)+side*2.9,1.55,.16,.18,'Timber')
                    if i%4==0:
                        bridge.box(x,deck-.6,road(x)+side*2.8,.28,4.8,.28,'Timber')
            objs.append(bridge.finish(collection))
        if (cx,cz)==(-2,1):
            ruins = Geometry('HillRuins',cx,cz)
            for i in range(7):
                a = i*math.tau/9
                x,z = -150+9*math.cos(a),150+9*math.sin(a)
                h = height(x,z)
                ruins.box(x,h+.4,z,2.8,.8,2.8,'Stone')
                for j in range(3 + (i%3)):
                    ruins.box(x,h+1.4+j*1.4,z,1.55,1.3,1.55,'StoneLight')
                ruins.box(x,h+1.0+(3+i%3)*1.4,z,2.2,.55,2.2,'Stone')
            objs.append(ruins.finish(collection))
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objs:
            obj.select_set(True)
            obj.location=(0,0,0)
        bpy.context.view_layer.objects.active=objs[0]
        bpy.ops.export_scene.fbx(filepath=str(asset_dir/'Models'/f'{key}.fbx'),use_selection=True,
            object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
            apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',bake_space_transform=True,
            mesh_smooth_type='OFF',use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,
            use_custom_props=False,path_mode='AUTO')
        for obj in objs: obj.location=(cx*SIZE,cz*SIZE,0)
        all_objects.extend(objs)
        manifest['chunks'].append({'key':key,'x':cx,'y':0,'z':cz,
                                  'model':f'Models/{key}.fbx','meshCount':len(objs)})
        print(f'EXPORTED {key}',flush=True)

# Validate exact border heights before publishing the manifest.
max_seam = 0
for (cx,cz), vertices in terrain_edges.items():
    if (cx+1,cz) in terrain_edges:
        other=terrain_edges[(cx+1,cz)]
        for j in range(41): max_seam=max(max_seam,abs(vertices[j*41+40][2]-other[j*41][2]))
    if (cx,cz+1) in terrain_edges:
        other=terrain_edges[(cx,cz+1)]
        for i in range(41): max_seam=max(max_seam,abs(vertices[40*41+i][2]-other[i][2]))
assert max_seam < 1e-6
manifest['statistics']={'chunks':49,'trees':tree_count,'meshes':len(all_objects),
                        'triangles':sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in all_objects),
                        'maxBorderHeightError':max_seam}
(asset_dir/'world-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')

# A separate studio collection provides an overview; it is never exported to FBX.
studio=bpy.data.collections.new('Preview Studio (not exported)')
scene.collection.children.link(studio)
def link_studio(obj):
    for col in list(obj.users_collection): col.objects.unlink(obj)
    studio.objects.link(obj)
bpy.ops.mesh.primitive_plane_add(size=5000,location=(0,0,-8))
backdrop=bpy.context.object
backdrop.name='Studio backdrop'
link_studio(backdrop)
backmat=bpy.data.materials.new('StudioSlate')
backmat.diffuse_color=(.095,.15,.18,1)
backdrop.data.materials.append(backmat)
bpy.ops.object.light_add(type='SUN',location=(0,0,400))
sun=bpy.context.object
sun.rotation_euler=(math.radians(28),math.radians(-24),math.radians(-30))
sun.data.energy=3
sun.data.angle=math.radians(8)
link_studio(sun)
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.35,.48,.65,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
bpy.ops.object.camera_add(location=(670,-840,650))
camera=bpy.context.object
camera.rotation_euler=(Vector((45,40,10))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=1030
camera.data.clip_end=5000
scene.camera=camera
link_studio(camera)
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1440
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(report_dir/'MeadowWorld-overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/'MeadowWorld.blend'), compress=True)
if args.render: bpy.ops.render.render(write_still=True)
print(json.dumps(manifest['statistics']),flush=True)
