Shader "Example/URPUnlitShaderBasic"
{
    // Defines the properties that can be set in the Material inspector window.
    Properties
    { 
        _Round("Round", float) = 10.0
        _Phase("Phase", float) = 0.0
        _Speed("Speed", float) = 10.0
    }

    
    SubShader
    {
        // Shared code block. Code in this block is shared between all passes in this subshader.
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #define PI 3.1415926
        ENDHLSL
        
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        Pass
        {
    
            // HLSL code block. Unity SRP uses HLSL as the shader language.
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            // Use Attributes struct as input to vertex shader.
            struct Attributes
            {
                float4 positionOS : POSITION; // positionOS contains vertex positions in object space.
                float2 uv : TEXCOORD0;
            };

            // Varyings struct as output from vertex shader and input to fragment shader.
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float _Round;
            float _Phase;
            float _Speed;

            //  The vertex shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // Transform vertex positions from object space to homogenous clip space.
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            // The fragment shader.
            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;

                // Move the UVs to the center.
                uv -= 0.5;

                // Set aspect ratio.
                uv *= _ScreenParams.x / _ScreenParams.y;

                // Convert to polar coordinates.
                float r = length(uv);
                float theta = atan2(uv.y, uv.x);

                // Rotate by time.
                float c = cos(r * PI * _Round + _Time * _Speed + _Phase);

                // Gamma correction.
                c = clamp(c, 0.0, 1);
                c= pow(c, 2.2);

                return (float4)c;
            }
            ENDHLSL
        }
    }
}

Shader "URPCustom/UnlitTexture"
{
    // 定义要在材质面板中显示的属性
    Properties
    {
        _BaseMap ("Base Texture",2D) = "white"{}
        _BaseColor("Base Color",Color)=(1,1,1,1)
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry"
            "RenderType"="Opaque"
        }

        // 共享的 HLSL 代码。HLSLPROGRAM 块中会自动包括该内容。
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
        CBUFFER_END
        ENDHLSL
    
        Pass
        {
            Tags{"LightMode"="UniversalForward"}

             // HLSL代码块。Unity SRP使用HLSL语言。
            HLSLPROGRAM 
            #pragma vertex vert
            #pragma fragment frag

            // 使用Attributes结构体作为顶点着色器的输入。
            struct Attributes
            {
                float4 positionOS : POSITION;  // positionOS变量包含物体空间中的顶点位置。
                float2 uv : TEXCOORD;
            };

            // Varyings结构体作为像素着色器的输入。
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // 顶点着色器
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // 将顶点位置从对象空间变换到齐次裁剪空间。
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            // 像素着色器
            half4  frag(Varyings IN):SV_Target
            {   
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                return color * _BaseColor;
            }
            ENDHLSL      
        }
    }
}

Shader "Example/URPUnlitShaderBasic"
{
    // 定义要在材质面板中显示的属性
    Properties
    { }

    // 包含Shader代码的SubShader块
    SubShader
    {
        // 共享的 HLSL 代码。HLSLPROGRAM 块中会自动包括该内容。
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        ENDHLSL
        
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        Pass
        {
    
            // HLSL代码块。Unity SRP使用HLSL语言。
            HLSLPROGRAM
            
            #pragma vertex vert  // 这一行定义了顶点着色器的名称
            #pragma fragment frag // 这一行定义了像素着色器的名称

            // 使用Attributes结构体作为顶点着色器的输入。
            struct Attributes
            {
                float4 positionOS   : POSITION; // positionOS变量包含物体空间中的顶点位置。
                float2 uv : TEXCOORD0;
            };

            // Varyings结构体作为像素着色器的输入。
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // 顶点着色器
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // 将顶点位置从对象空间变换到齐次裁剪空间。
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            // 像素着色器
            half4 frag(Varyings IN) : SV_Target
            {
                half4 customColor = half4(IN.uv.x, IN.uv.y, 0, 1);
                return customColor;
            }
            ENDHLSL
        }
    }
}
