using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
#if URP
using UnityEngine.Rendering.Universal;
#endif

namespace StylizedWater2.UnderwaterRendering
{
    [CustomEditor(typeof(UnderwaterRenderFeature))]
    public class RenderFeatureEditor : Editor
    {
        private SerializedProperty resources;
        private SerializedProperty settings;
        
        private SerializedProperty allowBlur;
        private SerializedProperty allowDistortion;
        private SerializedProperty distortionMode;
        
        private SerializedProperty directionalCaustics;
        private SerializedProperty accurateDirectionalCaustics;
        
        private SerializedProperty waterlineRefraction;

        private void OnEnable()
        {
            resources = serializedObject.FindProperty("resources");
            
            settings = serializedObject.FindProperty("settings");
            
            allowBlur = settings.FindPropertyRelative("allowBlur");
            allowDistortion = settings.FindPropertyRelative("allowDistortion");
            distortionMode = settings.FindPropertyRelative("distortionMode");
            
            directionalCaustics = settings.FindPropertyRelative("directionalCaustics");
            accurateDirectionalCaustics = settings.FindPropertyRelative("accurateDirectionalCaustics");
            
            waterlineRefraction = settings.FindPropertyRelative("waterlineRefraction");
        }

        public override void OnInspectorGUI()
        {
            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUILayout.LabelField($"Version {UnderwaterRenderer.Version}", EditorStyles.miniLabel);
            }
            EditorGUILayout.Space();
            

            
            serializedObject.Update();
            EditorGUI.BeginChangeCheck();

            EditorGUILayout.LabelField("Quality/Performance", EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(allowBlur);
            EditorGUILayout.PropertyField(allowDistortion);

            EditorGUILayout.Space();
            
            EditorGUILayout.PropertyField(distortionMode);

            EditorGUILayout.Space();
                
            EditorGUILayout.PropertyField(directionalCaustics);
            if (directionalCaustics.boolValue)
            {
                EditorGUI.indentLevel++;
                EditorGUILayout.PropertyField(accurateDirectionalCaustics);
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.Space();

            EditorGUILayout.PropertyField(waterlineRefraction);

            if (EditorGUI.EndChangeCheck())
            {
                serializedObject.ApplyModifiedProperties();
            }

            if (resources.objectReferenceValue == null)
            {
                EditorGUILayout.HelpBox("Internal shader resources object not referenced!", MessageType.Error);
                if (GUILayout.Button("Find & assign"))
                {
                    resources.objectReferenceValue = UnderwaterResources.Find();
                    serializedObject.ApplyModifiedProperties();
                }
            }
            
            UI.DrawFooter();
        }
    }
}