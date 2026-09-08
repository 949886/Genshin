#if URP && UNITY_6000_0_OR_NEWER
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace StylizedWater2.UnderwaterRendering
{
    public partial class UnderwaterMaskPass
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var camera = frameData.Get<UniversalCameraData>();
            var target = WaterRenderGraph.CreateTexture(graph, camera.cameraTargetDescriptor,
                "_UnderwaterMask", GraphicsFormat.R8_UNorm, DOWNSAMPLES, true);
            WaterRenderGraph.Record(graph, ProfilerTag, cmd =>
            {
                CoreUtils.SetRenderTarget(cmd, (RTHandle)target, ClearFlag.Color, Color.clear);
                cmd.DrawMesh(UnderwaterUtilities.WaterLineMesh, Matrix4x4.identity, Material, 0);
            }, writes: new[] { target }, globalTexture: target, globalProperty: waterMaskID);
        }
    }

    partial class DistortionSpherePass
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var camera = frameData.Get<UniversalCameraData>();
            var target = WaterRenderGraph.CreateTexture(graph, camera.cameraTargetDescriptor,
                _DistortionSphere, GraphicsFormat.R8_UNorm, 4);
            WaterRenderGraph.Record(graph, ProfilerTag, cmd =>
            {
                CoreUtils.SetRenderTarget(cmd, (RTHandle)target, ClearFlag.Color, Color.clear);
                cmd.DrawMesh(geoSphere, Matrix4x4.identity, DistortionSphereMaterial, 0);
            }, writes: new[] { target }, globalTexture: target, globalProperty: _DistortionSphereID);
        }
    }

    public partial class UnderwaterLinePass
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var targets = frameData.Get<UniversalResourceData>();
            var color = targets.activeColorTexture;
            var depth = targets.activeDepthTexture;
            var lights = frameData.Get<UniversalLightData>();
            CoreUtils.SetKeyword(Material, UnderwaterRenderer.REFRACTION_KEYWORD, settings.waterlineRefraction);
            CoreUtils.SetKeyword(Material, UnderwaterRenderer.TRANSLUCENCY_KEYWORD, renderFeature.keywordStates.translucency);
            CoreUtils.SetKeyword(Material, UnderwaterRenderer.WAVES_KEYWORD, renderFeature.keywordStates.waves);
            float width = UnderwaterRenderer.Instance.waterLineThickness * 0.1f;
            WaterRenderGraph.Record(graph, ProfilerTag, cmd =>
            {
                WaterRenderGraph.SetCameraTarget(cmd, color, depth);
                UnderwaterLighting.PassAmbientLighting(this, cmd);
                UnderwaterLighting.PassMainLight(cmd, lights);
                cmd.SetGlobalFloat(_WaterLineWidth, width);
                cmd.DrawMesh(UnderwaterUtilities.WaterLineMesh, Matrix4x4.identity, Material, 0, 0);
            }, writes: new[] { color, depth });
        }
    }

    public partial class RenderPass
    {
        // RenderGraph owns camera targets and transient copies. Resolve TextureHandles only while executing.
        protected void BlitToCamera(CommandBuffer cmd, TextureHandle color, TextureHandle depth,
            TextureHandle source, bool copyColor)
        {
            cmd.SetGlobalVector(_BlitScaleBiasRt, ScaleBias);
            cmd.SetGlobalVector(_BlitScaleBias, ScaleBias);
            if (copyColor)
            {
                CoreUtils.SetRenderTarget(cmd, (RTHandle)source, ClearFlag.None, Color.clear);
                Blitter.BlitTexture(cmd, color, ScaleBias, 0, false);
                cmd.SetGlobalTexture(sourceTexID, (RTHandle)source);
            }
            WaterRenderGraph.SetCameraTarget(cmd, color, depth);
            Blitter.BlitTexture(cmd, source, ScaleBias, Material, 0);
        }
    }

    partial class UnderwaterShadingPass
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var targets = frameData.Get<UniversalResourceData>();
            var color = targets.activeColorTexture;
            var depth = targets.activeDepthTexture;
            var source = targets.cameraDepthTexture;
            var lights = frameData.Get<UniversalLightData>();
            CoreUtils.SetKeyword(Material, SOURCE_DEPTH_NORMALS_KEYWORD,
                settings.directionalCaustics && settings.accurateDirectionalCaustics);
            CoreUtils.SetKeyword(Material, DEPTH_NORMALS_KEYWORD, settings.directionalCaustics);
            CoreUtils.SetKeyword(Material, UnderwaterRenderer.TRANSLUCENCY_KEYWORD, renderFeature.keywordStates.translucency);
            CoreUtils.SetKeyword(Material, UnderwaterRenderer.CAUSTICS_KEYWORD, renderFeature.keywordStates.caustics);
            WaterRenderGraph.Record(graph, ProfilerTag, cmd =>
            {
                UnderwaterLighting.PassAmbientLighting(this, cmd);
                UnderwaterLighting.PassMainLight(cmd, lights);
                BlitToCamera(cmd, color, depth, source, false);
            }, reads: new[] { source }, writes: new[] { color, depth });
        }
    }

    partial class UnderwaterPost
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var targets = frameData.Get<UniversalResourceData>();
            var color = targets.activeColorTexture;
            var depth = targets.activeDepthTexture;
            var descriptor = graph.GetTextureDesc(color);
            descriptor.name = "Underwater color copy";
            descriptor.msaaSamples = MSAASamples.None;
            descriptor.clearBuffer = false;
            var copy = graph.CreateTexture(descriptor);
            bool distortion = UnderwaterRenderer.Instance.enableDistortion && settings.allowDistortion;
            CoreUtils.SetKeyword(Material, BlurKeyword, UnderwaterRenderer.Instance.enableBlur && settings.allowBlur);
            CoreUtils.SetKeyword(Material, DistortionSSKeyword, distortion && settings.distortionMode == UnderwaterRenderFeature.Settings.DistortionMode.ScreenSpace);
            CoreUtils.SetKeyword(Material, DistortionWSKeyword, distortion && settings.distortionMode == UnderwaterRenderFeature.Settings.DistortionMode.CameraSpace);
            WaterRenderGraph.Record(graph, ProfilerTag, cmd =>
            {
                if (distortion) cmd.SetGlobalTexture(_DistortionNoise, resources.distortionNoise);
                BlitToCamera(cmd, color, depth, copy, true);
            }, writes: new[] { color, depth, copy });
        }
    }
}
#endif
