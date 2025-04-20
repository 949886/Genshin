Shader "Universal Render Pipeline/NiloToon/GenericStencilUnlit"
{
    Properties
    {
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Base
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Header(Base Color)]
        [MainTexture]_BaseMap("_BaseMap (Albedo) (Default White)", 2D) = "white" {} // Not using [Tex] to preserve tiling and offset GUI
        [HDR][MainColor]_BaseColor("_BaseColor (Default White)", Color) = (1,1,1,1)

        [Header(UV Animation)]
        _UvAnimSpeed("_UvAnimSpeed (xy)", Vector) = (0,0,0,0)

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Render States (can't use LWGUI's group, because of using [Enum(UnityEngine.Rendering.XXX)])
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////   
        [Header(Stencil)]
        // to match NiloToonCharacter's default stencil value
        _StencilRef("_StencilRef (Default 199)", Range(0,255)) = 199
        // 3 is Equal, so this shader will by default draw only on NiloTOon character pixels 
        [Enum(UnityEngine.Rendering.CompareFunction)]_StencilComp("_StencilComp (Default Equal)", Float) = 3  

        [Header(Polygon Face Culling)]
        // https://docs.unity3d.com/ScriptReference/Rendering.CullMode.html
        [Enum(UnityEngine.Rendering.CullMode)]_Cull("_Cull (Default Back)", Float) = 2

        [Header(Blending state)]
        // https://docs.unity3d.com/ScriptReference/Rendering.BlendMode.html
        // this section will only affect ForwardLit pass
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("_SrcBlend (Default SrcAlpha)", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("_DstBlend (Default OneMinusSrcAlpha)", Float) = 10

        [Header(ZWrite)]
        [ToggleUI]_ZWrite("_ZWrite (Default Off) ", Float) = 0

        [Header(ZTest)]
        // https://docs.unity3d.com/ScriptReference/Rendering.CompareFunction.html
        [Enum(UnityEngine.Rendering.CompareFunction)]_ZTest("_ZTest (Default LEqual) ", Float) = 4

        [Header(ColorMask)]
        // not using https://docs.unity3d.com/ScriptReference/Rendering.ColorWriteMask.html,
        // because we can't select RGB if we use Unity's ColorWriteMask.
        // So here we define 2 custom enum
        // 15 = 1111 (RGBA)
        // 14 = 1110 (RGB)
        [Enum(RGBA,15,RGB,14)]_ColorMask("_ColorMask (Default RGB)", Float) = 14 // 14 is RGB (1110)

        // perspective removal
        [HideInInspector]_PerspectiveRemovalAmount("_PerspectiveRemovalAmount", Range(0,1)) = 0
        [HideInInspector]_PerspectiveRemovalRadius("_PerspectiveRemovalRadius", Float) = 1
        [HideInInspector]_HeadBonePositionWS("_HeadBonePositionWS", Vector) = (0,0,0)
        [HideInInspector]_PerspectiveRemovalStartHeight("_PerspectiveRemovalStartHeight", Float) = 0 // ground
        [HideInInspector]_PerspectiveRemovalEndHeight("_PerspectiveRemovalEndHeight", Float) = 1 // a point above ground and below character head
    }
    SubShader
    {
        // draw after NiloToonCharacter shader, so when drawing this shader, stencil buffer's value is usable already
        Tags { "RenderType"="transparent" "Queue"="transparent-1" }
        
        // render state
        Cull [_Cull]
        ZWrite [_ZWrite]
        ZTest [_ZTest]
        Blend [_SrcBlend] [_DstBlend]
        ColorMask [_ColorMask]

        Stencil
        {
            Ref [_StencilRef]
            Comp [_StencilComp]
        }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Required by all Universal Render Pipeline shaders.
            // It will include Unity built-in shader variables (except the lighting variables)
            // (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
            // It will also include many utilitary functions. 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Include this if you are doing a lit shader. This includes lighting shader variables,
            // lighting and shadow functions
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // include a few small utility .hlsl files to help us
            #include "../../ShaderLibrary/NiloUtilityHLSL/NiloAllUtilIncludes.hlsl" 

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;

                // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
                //------------------------------------------------------------------------------------------------------------------------------
                UNITY_VERTEX_INPUT_INSTANCE_ID  // in non OpenGL / non PSSL, will turn into -> uint instanceID : SV_InstanceID;
                //------------------------------------------------------------------------------------------------------------------------------                   
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;

                // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
                //------------------------------------------------------------------------------------------------------------------------------
                UNITY_VERTEX_INPUT_INSTANCE_ID  // will turn into this in non OpenGL / non PSSL -> uint instanceID : SV_InstanceID;
                UNITY_VERTEX_OUTPUT_STEREO      // will turn into this in non OpenGL / non PSSL -> uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
                //------------------------------------------------------------------------------------------------------------------------------
            };

            sampler2D _BaseMap;

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float2 _UvAnimSpeed;

                half4 _BaseColor;

                // perspective removal
                float   _PerspectiveRemovalAmount; // total amount
                // perspective removal(sphere)
                float   _PerspectiveRemovalRadius;
                float3  _HeadBonePositionWS;
                // perspective removal(world height)
                float   _PerspectiveRemovalStartHeight; // usually is world space pos.y 0
                float   _PerspectiveRemovalEndHeight;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
                //------------------------------------------------------------------------------------------------------------------------------
                UNITY_SETUP_INSTANCE_ID(IN);                 // will turn into this in non OpenGL / non PSSL -> UnitySetupInstanceID(input.instanceID);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);      // will turn into this in non OpenGL / non PSSL -> output.instanceID = input.instanceID;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);  // will turn into this in non OpenGL / non PSSL -> output.stereoTargetEyeIndexAsRTArrayIdx = unity_StereoEyeIndex;
                //------------------------------------------------------------------------------------------------------------------------------

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                // perspective removal
                float3 positionWS = mul(UNITY_MATRIX_M, float4(IN.positionOS.xyz,1)).xyz;
                OUT.positionHCS = NiloDoPerspectiveRemoval(OUT.positionHCS,positionWS,_HeadBonePositionWS,_PerspectiveRemovalRadius,_PerspectiveRemovalAmount, _PerspectiveRemovalStartHeight, _PerspectiveRemovalEndHeight);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap) + frac(_UvAnimSpeed.xy * _Time.y);
                return OUT;
            }


            half4 frag (Varyings IN) : SV_Target
            {
                // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
                //------------------------------------------------------------------------------------------------------------------------------
                UNITY_SETUP_INSTANCE_ID(IN);                     // in non OpenGL / non PSSL, MACRO will turn into -> UnitySetupInstanceID(input.instanceID);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);    // in non OpenGL / non PSSL, MACRO will turn into -> unity_StereoEyeIndex = input.stereoTargetEyeIndexAsRTArrayIdx;
                //------------------------------------------------------------------------------------------------------------------------------

                // sample the texture
                half4 col = tex2D(_BaseMap, IN.uv) * _BaseColor;
                return col;
            }
            ENDHLSL
        }
    }
}
