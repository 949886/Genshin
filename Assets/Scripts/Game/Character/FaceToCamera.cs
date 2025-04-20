using UnityEditor;
using UnityEngine;

namespace Game.Character
{
    [ExecuteInEditMode]
    public class FaceToCamera : MonoBehaviour
    {
        public Camera camera;
        
        void Update() 
        {
#if UNITY_EDITOR
            transform.forward = SceneView.lastActiveSceneView.camera.transform.forward;
#else
            transform.forward = camera.transform.forward;
#endif
        }

    }
}