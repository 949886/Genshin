using System;
using UnityEditor;
using UnityEngine;

namespace Avatar.Loli.Catalyst.Nahida
{
    [RequireComponent(typeof(Renderer))]
    public class NahidaSwingShader : MonoBehaviour
    {
        private Renderer _renderer;
        private Material _material;
        
        // Main Color
        private static readonly int ColorID = UnityEngine.Shader.PropertyToID("_Color");
        
        [SerializeField, ColorUsage(true, true), OnChanged(nameof(OnColorChange))]
        private Color _color = new Color(0.694f, 0.831f, 0.525f, 0.408f);
        public Color Color
        {
            get => _color;
            set
            {
                _color = value;
                OnColorChange();
            }
        }
        
        // Glow Color
        private static readonly int GlowColorID = UnityEngine.Shader.PropertyToID("_GlowColor");
        
        [SerializeField, ColorUsage(true, true), OnChanged(nameof(OnGlowColorChange))]
        private Color _glowColor = new Color(0.343f, 1.0f, 0.0f, 1.0f);
        public Color GlowColor
        {
            get => _glowColor;
            set
            {
                _glowColor = value;
                OnGlowColorChange();
            }
        }
        
        // Emission Intensity
        private static readonly int EmissionIntensityID = UnityEngine.Shader.PropertyToID("_EmissionIntensity");
        
        [SerializeField, OnChanged(nameof(OnEmissionIntensityChange))]
        private float _emissionIntensity = 4.5f;
        public float EmissionIntensity
        {
            get => _emissionIntensity;
            set
            {
                _emissionIntensity = value;
                OnEmissionIntensityChange();
            }
        }
        
        // Alpha Clip
        private static readonly int AlphaClipID = UnityEngine.Shader.PropertyToID("_AlphaClip");
        
        [SerializeField, OnChanged(nameof(OnAlphaClipChange)), Range(0f, 1f)]
        private float _alphaClip = 0f;
        public float AlphaClip
        {
            get => _alphaClip;
            set
            {
                _alphaClip = value;
                OnAlphaClipChange();
            }
        }
        
        // Flow Speed
        private static readonly int FlowSpeedID = UnityEngine.Shader.PropertyToID("_FlowSpeed");
        
        [SerializeField, OnChanged(nameof(OnFlowSpeedChange))]
        private float _flowSpeed = 0.3f;
        public float FlowSpeed
        {
            get => _flowSpeed;
            set
            {
                _flowSpeed = value;
                OnFlowSpeedChange();
            }
        }
        
        // Noise Strength
        private static readonly int NoiseStrengthID = UnityEngine.Shader.PropertyToID("_NoiseStrength");
        
        [SerializeField, OnChanged(nameof(OnNoiseStrengthChange))]
        private float _noiseStrength = 0.15f;
        public float NoiseStrength
        {
            get => _noiseStrength;
            set
            {
                _noiseStrength = value;
                OnNoiseStrengthChange();
            }
        }
        
        // Noise Scale
        private static readonly int NoiseScaleID = UnityEngine.Shader.PropertyToID("_NoiseScale");
        
        [SerializeField, OnChanged(nameof(OnNoiseScaleChange))]
        private float _noiseScale = 2.5f;
        public float NoiseScale
        {
            get => _noiseScale;
            set
            {
                _noiseScale = value;
                OnNoiseScaleChange();
            }
        }
        
        // Glow Pulse Speed
        private static readonly int GlowPulseSpeedID = UnityEngine.Shader.PropertyToID("_GlowPulseSpeed");
        
        [SerializeField, OnChanged(nameof(OnGlowPulseSpeedChange))]
        private float _glowPulseSpeed = 1.2f;
        public float GlowPulseSpeed
        {
            get => _glowPulseSpeed;
            set
            {
                _glowPulseSpeed = value;
                OnGlowPulseSpeedChange();
            }
        }
        
        // Glow Pulse Min
        private static readonly int GlowPulseMinID = UnityEngine.Shader.PropertyToID("_GlowPulseMin");
        
        [SerializeField, OnChanged(nameof(OnGlowPulseMinChange))]
        private float _glowPulseMin = 0.7f;
        public float GlowPulseMin
        {
            get => _glowPulseMin;
            set
            {
                _glowPulseMin = value;
                OnGlowPulseMinChange();
            }
        }
        
        // Glow Pulse Max
        private static readonly int GlowPulseMaxID = UnityEngine.Shader.PropertyToID("_GlowPulseMax");
        
        [SerializeField, OnChanged(nameof(OnGlowPulseMaxChange))]
        private float _glowPulseMax = 1.5f;
        public float GlowPulseMax
        {
            get => _glowPulseMax;
            set
            {
                _glowPulseMax = value;
                OnGlowPulseMaxChange();
            }
        }
        
        // Outline Color
        private static readonly int OutlineColorID = UnityEngine.Shader.PropertyToID("_OutlineColor");
        
        [SerializeField, ColorUsage(true, true), OnChanged(nameof(OnOutlineColorChange))]
        private Color _outlineColor = new Color(0.868f, 1.0f, 0.726f, 0.0f);
        public Color OutlineColor
        {
            get => _outlineColor;
            set
            {
                _outlineColor = value;
                OnOutlineColorChange();
            }
        }
        
        // Outline Width
        private static readonly int OutlineWidthID = UnityEngine.Shader.PropertyToID("_OutlineWidth");
        
        [SerializeField, OnChanged(nameof(OnOutlineWidthChange))]
        private float _outlineWidth = 0.005f;
        public float OutlineWidth
        {
            get => _outlineWidth;
            set
            {
                _outlineWidth = value;
                OnOutlineWidthChange();
            }
        }
        
        // Outline Pulse Speed
        private static readonly int OutlinePulseSpeedID = UnityEngine.Shader.PropertyToID("_OutlinePulseSpeed");
        
        [SerializeField, OnChanged(nameof(OnOutlinePulseSpeedChange))]
        private float _outlinePulseSpeed = 1.5f;
        public float OutlinePulseSpeed
        {
            get => _outlinePulseSpeed;
            set
            {
                _outlinePulseSpeed = value;
                OnOutlinePulseSpeedChange();
            }
        }
        
        // Outline Pulse Min
        private static readonly int OutlinePulseMinID = UnityEngine.Shader.PropertyToID("_OutlinePulseMin");
        
        [SerializeField, OnChanged(nameof(OnOutlinePulseMinChange))]
        private float _outlinePulseMin = 0.8f;
        public float OutlinePulseMin
        {
            get => _outlinePulseMin;
            set
            {
                _outlinePulseMin = value;
                OnOutlinePulseMinChange();
            }
        }
        
        // Outline Pulse Max
        private static readonly int OutlinePulseMaxID = UnityEngine.Shader.PropertyToID("_OutlinePulseMax");
        
        [SerializeField, OnChanged(nameof(OnOutlinePulseMaxChange))]
        private float _outlinePulseMax = 1.2f;
        public float OutlinePulseMax
        {
            get => _outlinePulseMax;
            set
            {
                _outlinePulseMax = value;
                OnOutlinePulseMaxChange();
            }
        }

        private void Awake()
        {
            _renderer = GetComponent<Renderer>();
            _material = new Material(_renderer.material);
            _renderer.material = _material;      

            // Initialize shader properties with current values
            // OnColorChange();
            // OnGlowColorChange();
            // OnEmissionIntensityChange();
            // OnAlphaClipChange();
            // OnFlowSpeedChange();
            // OnNoiseStrengthChange();
            // OnNoiseScaleChange();
            // OnGlowPulseSpeedChange();
            // OnGlowPulseMinChange();
            // OnGlowPulseMaxChange();
            // OnOutlineColorChange();
            // OnOutlineWidthChange();
            // OnOutlinePulseSpeedChange();
            // OnOutlinePulseMinChange();
            // OnOutlinePulseMaxChange();
        }
        
        #if UNITY_EDITOR
        private void OnValidate()
        {
            // Set the material to the shader
            var path = AssetDatabase.GUIDToAssetPath("6d641b57ae3f5b0479bf21cf52ff7b20"); // NahidaSwingShader guid
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
            var renderer = GetComponent<Renderer>();
            
            if (renderer.sharedMaterial == null || renderer.sharedMaterial.shader != shader)
            {
                renderer.sharedMaterial = new Material(shader);
            }
            
            // Update material reference
            _material = renderer.sharedMaterial;
        }

        private void Reset()
        {
            _color = _material.GetColor(ColorID);
            _glowColor = _material.GetColor(GlowColorID);
            _emissionIntensity = _material.GetFloat(EmissionIntensityID);
            _alphaClip = _material.GetFloat(AlphaClipID);
            _flowSpeed = _material.GetFloat(FlowSpeedID);
            _noiseStrength = _material.GetFloat(NoiseStrengthID);
            _noiseScale = _material.GetFloat(NoiseScaleID);
        }
#endif
        
        public void OnColorChange()
        {
            Debug.Log($"OnColorChange: {_color}");
            if (_material != null)
                _material.SetColor(ColorID, _color);
        }
        
        public void OnGlowColorChange()
        {
            if (_material != null)
                _material.SetColor(GlowColorID, _glowColor);
        }
        
        public void OnEmissionIntensityChange()
        {
            if (_material != null)
                _material.SetFloat(EmissionIntensityID, _emissionIntensity);
        }
        
        public void OnAlphaClipChange()
        {
            if (_material != null)
                _material.SetFloat(AlphaClipID, _alphaClip);
        }
        
        public void OnFlowSpeedChange()
        {
            if (_material != null)
                _material.SetFloat(FlowSpeedID, _flowSpeed);
        }
        
        public void OnNoiseStrengthChange()
        {
            if (_material != null)
                _material.SetFloat(NoiseStrengthID, _noiseStrength);
        }
        
        public void OnNoiseScaleChange()
        {
            if (_material != null)
                _material.SetFloat(NoiseScaleID, _noiseScale);
        }
        
        public void OnGlowPulseSpeedChange()
        {
            if (_material != null)
                _material.SetFloat(GlowPulseSpeedID, _glowPulseSpeed);
        }
        
        public void OnGlowPulseMinChange()
        {
            if (_material != null)
                _material.SetFloat(GlowPulseMinID, _glowPulseMin);
        }
        
        public void OnGlowPulseMaxChange()
        {
            if (_material != null)
                _material.SetFloat(GlowPulseMaxID, _glowPulseMax);
        }
        
        public void OnOutlineColorChange()
        {
            if (_material != null)
                _material.SetColor(OutlineColorID, _outlineColor);
        }
        
        public void OnOutlineWidthChange()
        {
            if (_material != null)
                _material.SetFloat(OutlineWidthID, _outlineWidth);
        }
        
        public void OnOutlinePulseSpeedChange()
        {
            if (_material != null)
                _material.SetFloat(OutlinePulseSpeedID, _outlinePulseSpeed);
        }
        
        public void OnOutlinePulseMinChange()
        {
            if (_material != null)
                _material.SetFloat(OutlinePulseMinID, _outlinePulseMin);
        }
        
        public void OnOutlinePulseMaxChange()
        {
            if (_material != null)
                _material.SetFloat(OutlinePulseMaxID, _outlinePulseMax);
        }
    }
} 