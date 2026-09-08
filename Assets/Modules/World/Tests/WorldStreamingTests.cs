using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.AddressableAssets.ResourceLocators;
using UnityEngine.ResourceManagement;
using UnityEngine.ResourceManagement.ResourceLocations;
using UnityEngine.ResourceManagement.ResourceProviders;
using UnityEngine.ResourceManagement.Util;
using UnityEngine.TestTools;
using Object = UnityEngine.Object;

namespace Luna.World.Tests
{
    public class WorldStreamingTests
    {
        private const BindingFlags InternalStatic = BindingFlags.Static | BindingFlags.NonPublic;
        private readonly List<Chunk> _chunks = new List<Chunk>();
        private readonly List<GameObject> _objects = new List<GameObject>();
        private object _previousAddressables;
        private object _testAddressables;
        private bool _previousReinitialize;
        private ResourceLocationMap _locator;
        private DelayedPrefabProvider _provider;

        [SetUp]
        public void SetUp()
        {
            // Isolate the real Addressables resource manager from project catalogs and
            // remote servers. These internal field names are from Addressables 2.4.6.
            var instanceField = typeof(Addressables).GetField("m_AddressablesInstance", InternalStatic);
            var reinitializeField = typeof(Addressables).GetField("reinitializeAddressables", InternalStatic);
            _previousAddressables = instanceField.GetValue(null);
            _previousReinitialize = (bool) reinitializeField.GetValue(null);
            _testAddressables = Activator.CreateInstance(instanceField.FieldType, new object[] {new LRUCacheAllocationStrategy(100, 100, 10, 10)});
            instanceField.FieldType.GetField("hasStartedInitialization", BindingFlags.Instance | BindingFlags.NonPublic)
                .SetValue(_testAddressables, true);
            foreach (var callback in new[] {("m_OnHandleCompleteAction", "OnHandleCompleted"),
                ("m_OnSceneHandleCompleteAction", "OnSceneHandleCompleted"), ("m_OnHandleDestroyedAction", "OnHandleDestroyed")})
            {
                var field = instanceField.FieldType.GetField(callback.Item1, BindingFlags.Instance | BindingFlags.NonPublic);
                var method = instanceField.FieldType.GetMethod(callback.Item2, BindingFlags.Instance | BindingFlags.NonPublic);
                field.SetValue(_testAddressables, Delegate.CreateDelegate(field.FieldType, _testAddressables, method));
            }
            instanceField.SetValue(null, _testAddressables);
            reinitializeField.SetValue(null, false);

            _locator = new ResourceLocationMap("World streaming tests");
            _provider = new DelayedPrefabProvider();
            Addressables.AddResourceLocator(_locator);
            Addressables.ResourceManager.ResourceProviders.Add(_provider);
        }

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            foreach (var go in _objects) if (go != null) go.SetActive(false);
            foreach (var chunk in _chunks) chunk.Unload();
            _provider.CompleteAll();
            yield return null;
            foreach (var go in _objects) if (go != null) Object.Destroy(go);
            yield return null;
            Addressables.ResourceManager.Dispose();
            _testAddressables.GetType().GetMethod("ReleaseSceneManagerOperation", BindingFlags.Instance | BindingFlags.NonPublic)
                .Invoke(_testAddressables, null);
            typeof(Addressables).GetField("m_AddressablesInstance", InternalStatic).SetValue(null, _previousAddressables);
            typeof(Addressables).GetField("reinitializeAddressables", InternalStatic).SetValue(null, _previousReinitialize);
            _chunks.Clear();
            _objects.Clear();
        }

        [UnityTest]
        public IEnumerator MissingAddressUsesFallbackOnceWithoutErrors()
        {
            var chunk = CreateChunk(new Vector3Int(-1, 0, 1), CreateObject("Fallback"));
            var callbacks = 0;
            chunk.Load(_ => callbacks++);
            chunk.Load(_ => callbacks++);
            yield return WaitFor(() => chunk.State != Chunk.ChunkState.Loading);
            Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Loaded));
            Assert.That(chunk.Position, Is.EqualTo(new Vector3(-100, 0, 100)));
            Assert.That(callbacks, Is.EqualTo(1));
            Assert.That(_provider.Requests, Is.Empty);
            LogAssert.NoUnexpectedReceived();
        }

        [UnityTest]
        public IEnumerator MissingAddressWithoutFallbackBecomesEmptyAndCanReload()
        {
            var chunk = CreateChunk(Vector3Int.zero);
            chunk.Load(_ => Assert.Fail("An empty chunk must not invoke the instance callback."));
            yield return WaitFor(() => chunk.State == Chunk.ChunkState.Empty);
            Assert.That(chunk.GameObject, Is.Null);
            Assert.That(chunk.Position, Is.EqualTo(Vector3.zero));
            chunk.Reload(new Vector3Int(-2, 1, 3));
            yield return WaitFor(() => chunk.State == Chunk.ChunkState.Empty);
            Assert.That(chunk.Position, Is.EqualTo(new Vector3(-200, 100, 300)));
            chunk.Unload();
            Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Unloaded));
            LogAssert.NoUnexpectedReceived();
        }

        [UnityTest]
        public IEnumerator UnloadDuringLookupDoesNotInstantiateOrInvokeCallback()
        {
            var chunk = CreateChunk(Vector3Int.zero, CreateObject("Fallback"));
            chunk.Load(_ => Assert.Fail("An unloaded request completed."));
            chunk.Unload();
            yield return null;
            yield return null;
            Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Unloaded));
            Assert.That(chunk.GameObject, Is.Null);
        }

        [UnityTest]
        public IEnumerator ReloadIgnoresOldAssetCompletionAndReleasesBothAssets()
        {
            RegisterPrefab(Vector3Int.zero);
            RegisterPrefab(Vector3Int.right);
            var chunk = CreateChunk(Vector3Int.zero);
            var callbacks = 0;
            chunk.Load(_ => callbacks++);
            yield return WaitFor(() => _provider.Requests.Count == 1);
            chunk.Reload(Vector3Int.right, _ => callbacks++);
            yield return WaitFor(() => _provider.Requests.Count == 2);
            _provider.Complete("Chunk_X1_Y0_Z0");
            yield return WaitFor(() => chunk.State == Chunk.ChunkState.Loaded);
            var currentInstance = chunk.GameObject;
            _provider.Complete("Chunk_X0_Y0_Z0");
            yield return null;
            yield return null;
            Assert.That(callbacks, Is.EqualTo(1));
            Assert.That(chunk.GameObject, Is.SameAs(currentInstance));
            Assert.That(chunk.Position, Is.EqualTo(new Vector3(100, 0, 0)));
            Assert.That(_provider.Releases, Is.EqualTo(1));
            chunk.Unload();
            yield return null;
            Assert.That(_provider.Releases, Is.EqualTo(2));
            Assert.That(currentInstance == null, Is.True);
        }

        [UnityTest]
        public IEnumerator UnloadDuringAssetLoadReleasesLateResult()
        {
            RegisterPrefab(Vector3Int.zero);
            var chunk = CreateChunk(Vector3Int.zero);
            chunk.Load(_ => Assert.Fail("An unloaded asset request completed."));
            yield return WaitFor(() => _provider.Requests.Count == 1);
            chunk.Unload();
            _provider.CompleteAll();
            yield return null;
            yield return null;
            Assert.That(chunk.GameObject, Is.Null);
            Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Unloaded));
            Assert.That(_provider.Releases, Is.EqualTo(1));
        }

        [UnityTest]
        public IEnumerator CallbackCanUnloadWithoutLeavingLoadedState()
        {
            var chunk = CreateChunk(Vector3Int.zero, CreateObject("Fallback"));
            var completed = false;
            chunk.Load(_ => { completed = true; chunk.Unload(); });
            yield return WaitFor(() => completed);
            Assert.That(chunk.State, Is.EqualTo(Chunk.ChunkState.Unloaded));
            Assert.That(chunk.GameObject, Is.Null);
        }

        [UnityTest]
        public IEnumerator RendererTracksNegativeBoundariesAndTeleportsWithoutDuplicateCells()
        {
            var renderer = CreateRenderer(new Vector3(-0.1f, 210, -301), CreateObject("Fallback"));
            yield return WaitFor(() => renderer.transform.childCount == 27);
            AssertGrid(renderer, new Vector3Int(-1, 2, -4));
            foreach (var position in new[] {Vector3.zero, new Vector3(-0.1f, -0.1f, -0.1f),
                new Vector3(-100, -100, -100), new Vector3(-100.1f, -100.1f, -100.1f), new Vector3(2500, -900, 1700)})
            {
                renderer.player.transform.position = position;
                yield return null;
                yield return WaitFor(() => Grid(renderer).Cast<Chunk>().All(c => c.State == Chunk.ChunkState.Loaded));
                yield return null; // Destroyed instances leave the hierarchy at end of frame.
                AssertGrid(renderer, Vector3Int.FloorToInt(position / 100));
                Assert.That(renderer.transform.childCount, Is.EqualTo(27));
            }
        }

        [UnityTest]
        public IEnumerator RendererReassignsLoadingAndEmptyCellsAndCleansUpOnDisable()
        {
            RegisterPrefab(Vector3Int.zero);
            var renderer = CreateRenderer(Vector3.zero);
            yield return WaitFor(() => _provider.Requests.Count == 1);
            renderer.player.transform.position = new Vector3(1000, -1000, 1000);
            yield return null;
            yield return WaitFor(() => Grid(renderer).Cast<Chunk>().All(c => c.State == Chunk.ChunkState.Empty));
            AssertGrid(renderer, new Vector3Int(10, -10, 10));
            renderer.enabled = false;
            _provider.CompleteAll();
            yield return null;
            yield return null;
            Assert.That(Grid(renderer), Is.Null);
            Assert.That(renderer.transform.childCount, Is.Zero);
            Assert.That(_provider.Releases, Is.EqualTo(1));
            renderer.enabled = true;
            yield return WaitFor(() => Grid(renderer).Cast<Chunk>().All(c => c.State == Chunk.ChunkState.Empty));
            AssertGrid(renderer, new Vector3Int(10, -10, 10));
        }

        private GameObject CreateObject(string name)
        {
            var go = new GameObject(name);
            _objects.Add(go);
            return go;
        }

        private Chunk CreateChunk(Vector3Int coords, GameObject fallback = null)
        {
            var chunk = new Chunk(100, coords, fallback);
            _chunks.Add(chunk);
            return chunk;
        }

        private WorldRenderer CreateRenderer(Vector3 position, GameObject fallback = null)
        {
            var renderer = CreateObject("World").AddComponent<WorldRenderer>();
            renderer.player = CreateObject("Player");
            renderer.player.transform.position = position;
            renderer.chunkSize = 100;
            renderer.renderDistance = 1;
            renderer.fallback = fallback;
            return renderer;
        }

        private void RegisterPrefab(Vector3Int coords)
        {
            var key = $"Chunk_X{coords.x}_Y{coords.y}_Z{coords.z}";
            _provider.Prefabs.Add(key, CreateObject(key));
            _locator.Add(key, new ResourceLocationBase(key, key, _provider.ProviderId, typeof(GameObject)));
        }

        private static Chunk[,,] Grid(WorldRenderer renderer) => (Chunk[,,]) typeof(WorldRenderer)
            .GetField("_chunks", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(renderer);

        private static void AssertGrid(WorldRenderer renderer, Vector3Int center)
        {
            var chunks = Grid(renderer).Cast<Chunk>().ToArray();
            Assert.That(chunks.Length, Is.EqualTo(27));
            Assert.That(chunks.Select(c => c.Coords).Distinct().Count(), Is.EqualTo(27));
            foreach (var chunk in chunks)
            {
                var delta = chunk.Coords - center;
                Assert.That(Mathf.Max(Mathf.Abs(delta.x), Mathf.Abs(delta.y), Mathf.Abs(delta.z)), Is.LessThanOrEqualTo(1));
            }
        }

        private static IEnumerator WaitFor(Func<bool> condition)
        {
            for (var i = 0; i < 120 && !condition(); i++) yield return null;
            Assert.That(condition(), Is.True, "Streaming did not reach the expected state within 120 frames.");
        }

        private sealed class DelayedPrefabProvider : ResourceProviderBase
        {
            public readonly Dictionary<string, GameObject> Prefabs = new Dictionary<string, GameObject>();
            public readonly Dictionary<string, ProvideHandle> Requests = new Dictionary<string, ProvideHandle>();
            private readonly HashSet<string> _completed = new HashSet<string>();
            public int Releases { get; private set; }
            public override void Provide(ProvideHandle handle) => Requests.Add(handle.Location.PrimaryKey, handle);
            public override void Release(IResourceLocation location, object asset) => Releases++;

            public void Complete(string key)
            {
                if (_completed.Add(key)) Requests[key].Complete(Prefabs[key], true, null);
            }

            public void CompleteAll()
            {
                foreach (var key in Requests.Keys.ToArray()) Complete(key);
            }
        }
    }
}
