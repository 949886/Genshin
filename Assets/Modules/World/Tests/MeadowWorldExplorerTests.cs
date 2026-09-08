using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.TestTools;
using Object = UnityEngine.Object;

namespace Luna.World.Tests
{
    public class MeadowWorldExplorerTests
    {
        private GameObject _world, _camera, _player;
        private Keyboard _keyboard;
        private InputSettings _previousSettings;
        private InputSettings _testSettings;

        [SetUp]
        public void ConfigureHeadlessInput()
        {
            _previousSettings = InputSystem.settings;
            _testSettings = Object.Instantiate(_previousSettings);
            // Batch tests have no focused Game view; leave the user's settings untouched.
#if UNITY_EDITOR
            _testSettings.editorInputBehaviorInPlayMode = InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
#endif
            _testSettings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
            InputSystem.settings = _testSettings;
        }

        [UnityTearDown]
        public IEnumerator Cleanup()
        {
            if (_keyboard != null) InputSystem.RemoveDevice(_keyboard);
            InputSystem.settings = _previousSettings;
            Object.Destroy(_testSettings);
            if (_world != null) _world.SetActive(false);
            if (_camera != null) _camera.SetActive(false);
            Object.Destroy(_world);
            Object.Destroy(_camera);
            Object.Destroy(_player);
            yield return null;
        }

        [UnityTest]
        public IEnumerator CorrectsOldCameraAndLoadsVisibleTerrain()
        {
            var explorer = CreateExplorer();
            var camera = explorer.GetComponent<Camera>();
            Assert.That(camera.orthographic, Is.False);
            Assert.That(camera.enabled, Is.True);
            Assert.That(camera.transform.position, Is.EqualTo(new Vector3(-40, 85, -60)));
            Assert.That(_world.GetComponent<WorldRenderer>().fallback, Is.Null);
            yield return WaitForWorld();
            Physics.SyncTransforms();
            Assert.That(Physics.Raycast(camera.transform.position, camera.transform.forward, out _, 500), Is.True,
                "The actual Game camera must face collidable world geometry, not the sky or the underside of the terrain.");
        }

        [UnityTest]
        public IEnumerator MovementLookAndHighAltitudeKeepGroundStreaming()
        {
            var explorer = CreateExplorer();
            yield return WaitForWorld();
            var start = explorer.transform.position;
            var rotation = explorer.transform.rotation;
            explorer.ApplyInput(Vector3.forward, new Vector2(90, -30), true, .1f);
            Assert.That(Vector3.Distance(start, explorer.transform.position), Is.EqualTo(9).Within(.001));
            Assert.That(Quaternion.Angle(rotation, explorer.transform.rotation), Is.GreaterThan(1));
            for (var i = 0; i < 20; i++) explorer.ApplyInput(Vector3.up, Vector2.zero, true, .1f);
            Assert.That(explorer.transform.position.y, Is.GreaterThan(100));
            Assert.That(_player.transform.position.y, Is.EqualTo(50));
            explorer.ResetView();
            Assert.That(explorer.transform.position, Is.EqualTo(start));
        }

        [UnityTest]
        public IEnumerator WKeyMovesCameraThroughTheInputSystem()
        {
            var explorer = CreateExplorer();
            yield return WaitForWorld();
            _keyboard = InputSystem.AddDevice<Keyboard>();
            var start = explorer.transform.position;
            InputSystem.QueueStateEvent(_keyboard, new KeyboardState(Key.W));
            InputSystem.Update();
            yield return null;
            yield return null;
            yield return null;
            InputSystem.QueueStateEvent(_keyboard, new KeyboardState());
            InputSystem.Update();
            Assert.That(Vector3.Dot(explorer.transform.position - start, explorer.transform.forward), Is.GreaterThan(0),
                "Pressing W must move the Game camera, not just an unused Player transform.");
        }

        private MeadowWorldExplorer CreateExplorer()
        {
            _world = new GameObject("World");
            _player = new GameObject("Player");
            _world.AddComponent<WorldRenderer>().player = _player;
            _camera = new GameObject("Main Camera");
            var camera = _camera.AddComponent<Camera>();
            camera.transform.position = new Vector3(0, -20, 0);
            camera.orthographic = true;
            return _camera.AddComponent<MeadowWorldExplorer>();
        }

        private IEnumerator WaitForWorld()
        {
            var deadline = Time.realtimeSinceStartup + 30;
            while (_world.transform.childCount != 49 && Time.realtimeSinceStartup < deadline) yield return null;
            Assert.That(_world.transform.childCount, Is.EqualTo(49));
        }
    }
}
