using UnityEngine;
using UnityEngine.SceneManagement;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace Luna.World
{
    [RequireComponent(typeof(Camera))]
    [DisallowMultipleComponent]
    public sealed class MeadowWorldExplorer : MonoBehaviour
    {
        public const string ScenePath = "Assets/Modules/World/World Partition.unity";
        public float moveSpeed = 30;
        public float lookSensitivity = .12f;
        public bool showControls = true;

        private WorldRenderer _world;
        private Transform _observer;
        private float _yaw, _pitch;
        private bool _looking;

        // Also upgrades a scene already open in the editor before the YAML changed.
        // Restrict this to the demo scene so other game cameras are unaffected.
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void RegisterSceneHook()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneLoaded += OnSceneLoaded;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void AttachToOpenScene()
        {
            for (var i = 0; i < SceneManager.sceneCount; i++) Attach(SceneManager.GetSceneAt(i));
        }

        private static void OnSceneLoaded(Scene scene, LoadSceneMode mode) => Attach(scene);

        private static void Attach(Scene scene)
        {
            if (scene.path != ScenePath) return;
            Camera selected = null;
            foreach (var root in scene.GetRootGameObjects())
            {
                if (root.GetComponentInChildren<MeadowWorldExplorer>(true) != null) return;
                foreach (var camera in root.GetComponentsInChildren<Camera>())
                    if (selected == null || camera.CompareTag("MainCamera")) selected = camera;
            }
            if (selected != null) selected.gameObject.AddComponent<MeadowWorldExplorer>();
        }

        private void Awake()
        {
            foreach (var root in gameObject.scene.GetRootGameObjects())
            {
                _world = root.GetComponentInChildren<WorldRenderer>();
                if (_world != null) break;
            }
            if (_world == null)
            {
                Debug.LogError("MeadowWorldExplorer requires a WorldRenderer in the same scene.", this);
                enabled = false;
                return;
            }

            // A legacy Cinemachine Brain would overwrite the free-flight camera pose.
            foreach (var behaviour in GetComponents<MonoBehaviour>())
                if (behaviour != null && behaviour.GetType().Name == "CinemachineBrain") behaviour.enabled = false;

            var camera = GetComponent<Camera>();
            camera.enabled = true;
            camera.orthographic = false;
            camera.usePhysicalProperties = false;
            camera.nearClipPlane = .1f;
            camera.farClipPlane = 1500;
            camera.fieldOfView = 60;
            camera.cullingMask = ~0;
            camera.rect = new Rect(0, 0, 1, 1);
            camera.targetTexture = null;
            camera.ResetProjectionMatrix();

            _world.enabled = false;
            _world.chunkSize = 100;
            _world.renderDistance = 3;
            _world.fallback = null;
            if (_world.player == null)
            {
                _world.player = new GameObject("World Observer");
                _world.player.transform.SetParent(_world.transform);
            }
            _observer = _world.player.transform;
            ResetView();
            _world.enabled = true;
        }

        public void ResetView()
        {
            transform.position = new Vector3(-40, 85, -60);
            transform.rotation = Quaternion.LookRotation(new Vector3(70, 9, 80) - transform.position);
            _yaw = transform.eulerAngles.y;
            _pitch = Mathf.DeltaAngle(0, transform.eulerAngles.x);
            UpdateObserver();
        }

        private void Update()
        {
            if (_observer == null) return;
            var movement = Vector3.zero;
            var look = Vector2.zero;
            var boost = false;
            var looking = false;
#if ENABLE_INPUT_SYSTEM
            var keyboard = Keyboard.current;
            var mouse = Mouse.current;
            if (keyboard != null)
            {
                movement.x = (keyboard.dKey.isPressed ? 1 : 0) - (keyboard.aKey.isPressed ? 1 : 0);
                movement.z = (keyboard.wKey.isPressed ? 1 : 0) - (keyboard.sKey.isPressed ? 1 : 0);
                movement.y = (keyboard.eKey.isPressed ? 1 : 0) - (keyboard.qKey.isPressed ? 1 : 0);
                boost = keyboard.leftShiftKey.isPressed || keyboard.rightShiftKey.isPressed;
                if (keyboard.homeKey.wasPressedThisFrame) ResetView();
            }
            if (mouse != null)
            {
                looking = mouse.rightButton.isPressed;
                if (looking) look = mouse.delta.ReadValue();
            }
#elif ENABLE_LEGACY_INPUT_MANAGER
            movement.x = (Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0);
            movement.z = (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0);
            movement.y = (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0);
            boost = Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);
            looking = Input.GetMouseButton(1);
            if (looking) look = new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y")) * 12;
            if (Input.GetKeyDown(KeyCode.Home)) ResetView();
#endif
            if (looking != _looking)
            {
                _looking = looking;
                Cursor.lockState = looking ? CursorLockMode.Locked : CursorLockMode.None;
                Cursor.visible = !looking;
            }
            ApplyInput(movement, look, boost, Time.unscaledDeltaTime);
        }

        public void ApplyInput(Vector3 movement, Vector2 look, bool boost, float deltaTime)
        {
            _yaw += look.x * lookSensitivity;
            _pitch = Mathf.Clamp(_pitch - look.y * lookSensitivity, -85, 85);
            transform.rotation = Quaternion.Euler(_pitch, _yaw, 0);
            var direction = transform.right * movement.x + transform.forward * movement.z + Vector3.up * movement.y;
            var position = transform.position + Vector3.ClampMagnitude(direction, 1) *
                (moveSpeed * (boost ? 3 : 1) * Mathf.Clamp(deltaTime, 0, .1f));
            position.x = Mathf.Clamp(position.x, -299, 399);
            position.z = Mathf.Clamp(position.z, -299, 399);
            position.y = Mathf.Clamp(position.y, 8, 250);
            if (Physics.Raycast(new Vector3(position.x, 300, position.z), Vector3.down, out var ground, 300,
                    Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore))
                position.y = Mathf.Max(position.y, ground.point.y + 3);
            transform.position = position;
            UpdateObserver();
        }

        private void UpdateObserver()
        {
            if (_observer == null) return;
            var ahead = Vector3.ProjectOnPlane(transform.forward, Vector3.up).normalized * 100;
            var position = transform.position + ahead;
            // The terrain occupies Y0 even when the observer flies above 100 metres.
            position.y = 50;
            _observer.position = position;
        }

        private void OnGUI()
        {
            if (showControls)
                GUI.Box(new Rect(12, 12, 630, 30), "WASD: Move   |   RMB: Look   |   Q/E: Down/Up   |   Shift: Faster   |   Home: Reset");
        }

        private void OnApplicationFocus(bool focused) { if (!focused) ReleaseCursor(); }
        private void OnDisable() => ReleaseCursor();
        private void ReleaseCursor()
        {
            if (!_looking) return;
            _looking = false;
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }
}
