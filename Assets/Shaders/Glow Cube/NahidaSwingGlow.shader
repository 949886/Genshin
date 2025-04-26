Shader "Nahida/SwingGlow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _FlowerTex ("Flower Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        
        _Color ("Color", Color) = (1,1,1,1)
        _EmissionColor ("Emission Color", Color) = (0,1,0,1)
        _FlowerColor ("Flower Color", Color) = (1,1,1,1)
        
        _AlphaBrightness ("Alpha Brightness", Range(0, 10)) = 2
        _ColorBrightness ("Color Brightness", Range(0, 20)) = 5
        _AlphaEdgeFade ("Alpha Edge Fade", Range(0, 1)) = 0.5
        
        _PulseMagnitude ("Pulse Magnitude", Range(0, 1)) = 0.2
        _PulseFrequency ("Pulse Frequency", Range(0, 5)) = 2
        
        _NoiseSpeed ("Noise Speed", Vector) = (0.1, 0.1, 0, 0)
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD1;
                float2 noiseUV : TEXCOORD2;
            };

            sampler2D _MainTex;
            sampler2D _EmissionMap;
            sampler2D _FlowerTex;
            sampler2D _NoiseTex;
            
            float4 _MainTex_ST;
            float4 _NoiseSpeed;
            float4 _Color;
            float4 _EmissionColor;
            float4 _FlowerColor;
            
            float _AlphaBrightness;
            float _ColorBrightness;
            float _AlphaEdgeFade;
            float _PulseMagnitude;
            float _PulseFrequency;
            float _NoiseStrength;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.noiseUV = o.uv + _Time.y * _NoiseSpeed.xy;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Base color and alpha
                fixed4 col = tex2D(_MainTex, i.uv);
                col *= _Color;
                
                // Emission map for glow
                fixed4 emission = tex2D(_EmissionMap, i.uv);
                
                // Flower texture
                fixed4 flower = tex2D(_FlowerTex, i.uv);
                
                // Add noise texture for movement and variation
                fixed4 noise = tex2D(_NoiseTex, i.noiseUV);
                
                // Calculate pulse effect
                float pulse = 1.0 + _PulseMagnitude * sin(_Time.y * _PulseFrequency);
                
                // Apply noise to emission
                float noiseEffect = lerp(1.0, noise.r, _NoiseStrength);
                
                // Add flower highlights
                col.rgb += flower.rgb * _FlowerColor.rgb * emission.r * pulse * _ColorBrightness;
                
                // Add emission glow
                col.rgb += emission.rgb * _EmissionColor.rgb * pulse * _ColorBrightness * noiseEffect;
                
                // Calculate alpha with edge fade
                float alpha = col.a * emission.a * _AlphaBrightness;
                alpha *= lerp(_AlphaEdgeFade, 1.0, noise.g);
                
                // Return final color with alpha
                return fixed4(col.rgb, alpha);
            }
            ENDCG
        }
    }
} 