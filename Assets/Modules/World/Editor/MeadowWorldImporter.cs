using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
using UnityEngine;

namespace Luna.World.Editor
{
    /// <summary>Imports the Blender exports without depending on Blender on the player's machine.</summary>
    public static class MeadowWorldImporter
    {
        public const string Root = "Assets/Scenes/WorldPartitions/MeadowWorld";
        public const string GroupName = "World Chunks";

        [Serializable] public class WorldManifest
        {
            public int chunkSize;
            public MaterialInfo[] materials;
            public ChunkInfo[] chunks;
            public Vector3 spawn;
            public Vector3 camera;
            public Vector3 cameraTarget;
        }
        [Serializable] public class MaterialInfo { public string name; public Color color; public float smoothness; }
        [Serializable] public class ChunkInfo { public string key; public int x, y, z; public string model; public int meshCount; }

        [MenuItem("Tools/World Partition/Import Blender Meadow World")]
        public static void ImportAll()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Stop Play Mode before importing world chunks.");
            var manifest = JsonUtility.FromJson<WorldManifest>(File.ReadAllText(Root + "/world-manifest.json"));
            if (manifest.chunks.Length != 49 || manifest.chunkSize != 100)
                throw new InvalidDataException("Expected the 49-cell, 100-metre Blender export.");
            EnsureFolder(Root + "/Materials");
            EnsureFolder(Root + "/Prefabs");
            var shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null) throw new InvalidOperationException("The generated world requires the project's URP/Lit shader.");
            var materials = new Dictionary<string, Material>();
            foreach (var info in manifest.materials)
            {
                var path = Root + "/Materials/" + info.name + ".mat";
                var material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (material == null)
                {
                    material = new Material(shader);
                    AssetDatabase.CreateAsset(material, path);
                }
                material.shader = shader;
                material.SetColor("_BaseColor", info.color);
                material.SetFloat("_Smoothness", info.smoothness);
                material.SetFloat("_Metallic", 0);
                material.SetFloat("_Cull", info.name == "Grass" || info.name == "Flowers" ? 0 : 2);
                material.enableInstancing = true;
                EditorUtility.SetDirty(material);
                materials.Add(info.name, material);
            }

            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                settings = AddressableAssetSettings.Create("Assets/AddressableAssetsData", "AddressableAssetSettings", true, true);
                AddressableAssetSettingsDefaultObject.Settings = settings;
            }
            var group = settings.FindGroup(GroupName) ?? settings.CreateGroup(GroupName, false, false, false, null,
                typeof(BundledAssetGroupSchema), typeof(ContentUpdateGroupSchema));
            var schema = group.GetSchema<BundledAssetGroupSchema>();
            schema.BuildPath.SetVariableByName(settings, AddressableAssetSettings.kLocalBuildPath);
            schema.LoadPath.SetVariableByName(settings, AddressableAssetSettings.kLocalLoadPath);
            schema.BundleMode = BundledAssetGroupSchema.BundlePackingMode.PackSeparately;
            schema.IncludeInBuild = true;
            schema.IncludeAddressInCatalog = true;

            foreach (var chunk in manifest.chunks)
            {
                var modelPath = Root + "/" + chunk.model;
                var importer = (ModelImporter) AssetImporter.GetAtPath(modelPath);
                if (importer == null) throw new FileNotFoundException(modelPath);
                importer.globalScale = 1;
                importer.useFileScale = true;
                importer.bakeAxisConversion = true;
                importer.importAnimation = false;
                importer.importCameras = false;
                importer.importLights = false;
                importer.importNormals = ModelImporterNormals.Import;
                importer.importTangents = ModelImporterTangents.None;
                importer.meshCompression = ModelImporterMeshCompression.Off;
                importer.isReadable = true;
                importer.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
                foreach (var item in materials)
                    importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), item.Key), item.Value);
                importer.SaveAndReimport();

                var model = AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
                var instance = (GameObject) PrefabUtility.InstantiatePrefab(model);
                try
                {
                    instance.name = chunk.key;
                    instance.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
                    instance.transform.localScale = Vector3.one;
                    foreach (var filter in instance.GetComponentsInChildren<MeshFilter>())
                    {
                        // Blender gives same-named objects in different collections .001 suffixes.
                        filter.gameObject.name = filter.name.Split('.')[0];
                        if (new[] {"Terrain", "Rocks", "Trunks", "Bridge", "HillRuins"}.Contains(filter.name))
                        {
                            var collider = filter.gameObject.GetComponent<MeshCollider>();
                            if (collider == null) collider = filter.gameObject.AddComponent<MeshCollider>();
                            collider.sharedMesh = filter.sharedMesh;
                        }
                    }
                    ValidateInstance(instance, chunk);
                    var path = Root + "/Prefabs/" + chunk.key + ".prefab";
                    PrefabUtility.SaveAsPrefabAsset(instance, path);
                    var entry = settings.CreateOrMoveEntry(AssetDatabase.AssetPathToGUID(path), group);
                    entry.address = chunk.key;
                }
                finally { UnityEngine.Object.DestroyImmediate(instance); }
            }
            EditorUtility.SetDirty(schema);
            EditorUtility.SetDirty(group);
            EditorUtility.SetDirty(settings);
            AssetDatabase.SaveAssets();
            ValidateBorders(manifest);
            Debug.Log("MEADOW_WORLD_VALIDATED: 49 addressable prefabs, imported scale, upward normals, shared materials, colliders and all shared terrain borders.");
        }

        private static void ValidateInstance(GameObject instance, ChunkInfo chunk)
        {
            var filters = instance.GetComponentsInChildren<MeshFilter>();
            if (filters.Length != chunk.meshCount) throw new InvalidDataException(chunk.key + ": mesh count mismatch.");
            var terrain = filters.Single(f => f.name == "Terrain");
            var points = terrain.sharedMesh.vertices.Select(terrain.transform.TransformPoint).ToArray();
            var bounds = new Bounds(points[0], Vector3.zero);
            foreach (var point in points) bounds.Encapsulate(point);
            Debug.Log($"{chunk.key}: terrain bounds min={bounds.min:F3}, max={bounds.max:F3}");
            if (Mathf.Abs(bounds.min.x) > .001f || Mathf.Abs(bounds.min.z) > .001f ||
                Mathf.Abs(bounds.max.x - 100) > .001f || Mathf.Abs(bounds.max.z - 100) > .001f ||
                bounds.min.y < 0 || bounds.max.y >= 100)
                throw new InvalidDataException(chunk.key + ": imported axes or scale do not match the 100-metre cell.");
            foreach (var normal in terrain.sharedMesh.normals)
                if (terrain.transform.TransformDirection(normal).y <= 0)
                    throw new InvalidDataException(chunk.key + ": inverted terrain normal.");
            foreach (var renderer in instance.GetComponentsInChildren<MeshRenderer>())
                foreach (var material in renderer.sharedMaterials)
                    if (material == null || !AssetDatabase.GetAssetPath(material).StartsWith(Root + "/Materials/"))
                        throw new InvalidDataException(chunk.key + ": unmapped material on " + renderer.name);
        }

        private static void ValidateBorders(WorldManifest manifest)
        {
            var samples = new Dictionary<Vector2, Vector3>();
            var matches = 0;
            foreach (var chunk in manifest.chunks)
            {
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "/Prefabs/" + chunk.key + ".prefab");
                var terrain = prefab.GetComponentsInChildren<MeshFilter>().Single(f => f.name == "Terrain");
                var verts = terrain.sharedMesh.vertices;
                var normals = terrain.sharedMesh.normals;
                for (var i = 0; i < verts.Length; i++)
                {
                    var p = terrain.transform.TransformPoint(verts[i]);
                    if (Mathf.Abs(p.x) > .001f && Mathf.Abs(p.z) > .001f &&
                        Mathf.Abs(p.x - 100) > .001f && Mathf.Abs(p.z - 100) > .001f) continue;
                    var key = new Vector2(Mathf.Round((p.x + chunk.x * 100) * 1000), Mathf.Round((p.z + chunk.z * 100) * 1000));
                    var n = terrain.transform.TransformDirection(normals[i]);
                    var sample = new Vector3(p.y, n.x, n.z);
                    if (samples.TryGetValue(key, out var other))
                    {
                        if (Vector3.Distance(sample, other) > .002f)
                            throw new InvalidDataException(chunk.key + ": terrain seam at " + key);
                        matches++;
                    }
                    else samples.Add(key, sample);
                }
            }
            if (matches < 3000) throw new InvalidDataException("Insufficient shared border samples.");
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            var parent = Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }
    }
}
