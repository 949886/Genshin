using System.Collections;
using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using Object = UnityEngine.Object;

namespace Luna.World.Tests
{
    public class MeadowWorldTests
    {
        [UnityTest]
        public IEnumerator GeneratedPrefabsLoadThroughAddressablesWithMaterialsAndColliders()
        {
            var chunks = new List<Chunk>();
            var instances = new List<GameObject>();
            try
            {
                for (var x = -3; x <= 3; x++)
                    for (var z = -3; z <= 3; z++)
                    {
                        var chunk = new Chunk(100, new Vector3Int(x, 0, z));
                        chunks.Add(chunk);
                        chunk.Load(instances.Add);
                    }
                var deadline = Time.realtimeSinceStartup + 30;
                while (chunks.Any(c => c.State == Chunk.ChunkState.Loading) && Time.realtimeSinceStartup < deadline)
                    yield return null;
                Assert.That(instances.Count, Is.EqualTo(49), "All generated keys must resolve to real prefabs, without a fallback.");
                Physics.SyncTransforms();
                foreach (var chunk in chunks)
                {
                    Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Loaded));
                    Assert.That(chunk.Position, Is.EqualTo((Vector3) chunk.Coords * 100));
                    Assert.That(chunk.GameObject.GetComponentsInChildren<MeshCollider>().Length, Is.GreaterThanOrEqualTo(1));
                    var ground = chunk.GameObject.GetComponentsInChildren<MeshCollider>().Single(c => c.name == "Terrain");
                    var ray = new Ray(chunk.Position + new Vector3(50, 99, 50), Vector3.down);
                    Assert.That(ground.Raycast(ray, out _, 100), Is.True, "Terrain must be collidable from above: " + chunk.Coords);
                    foreach (var renderer in chunk.GameObject.GetComponentsInChildren<MeshRenderer>())
                        foreach (var material in renderer.sharedMaterials)
                        {
                            Assert.That(material, Is.Not.Null);
                            Assert.That(material.shader.name, Is.EqualTo("Universal Render Pipeline/Lit"));
                        }
                }
            }
            finally { foreach (var chunk in chunks) chunk.Unload(); }
            yield return null;
            Assert.That(instances.All(go => go == null), Is.True);
            LogAssert.NoUnexpectedReceived();
        }

        [UnityTest]
        public IEnumerator WorldRendererStreamsGroundCellsAndLeavesSkyAndOutsideWorldEmpty()
        {
            var world = new GameObject("Generated World Test");
            var player = new GameObject("Observer");
            try
            {
                player.transform.position = new Vector3(0, 50, 0);
                var renderer = world.AddComponent<WorldRenderer>();
                renderer.player = player;
                renderer.chunkSize = 100;
                renderer.renderDistance = 3;
                yield return WaitForChildren(world.transform, 49);
                foreach (Transform child in world.transform) Assert.That(child.position.y, Is.Zero);
                player.transform.position = new Vector3(350, 50, 350);
                yield return null;
                yield return WaitForChildren(world.transform, 16);
                foreach (Transform child in world.transform)
                {
                    Assert.That(child.position.x, Is.InRange(0, 300));
                    Assert.That(child.position.z, Is.InRange(0, 300));
                }
                renderer.enabled = false;
                yield return WaitForChildren(world.transform, 0);
            }
            finally
            {
                world.SetActive(false);
                Object.Destroy(world);
                Object.Destroy(player);
            }
            yield return null;
            LogAssert.NoUnexpectedReceived();
        }

        private static IEnumerator WaitForChildren(Transform parent, int count)
        {
            var deadline = Time.realtimeSinceStartup + 30;
            while (parent.childCount != count && Time.realtimeSinceStartup < deadline) yield return null;
            Assert.That(parent.childCount, Is.EqualTo(count));
        }
    }
}
