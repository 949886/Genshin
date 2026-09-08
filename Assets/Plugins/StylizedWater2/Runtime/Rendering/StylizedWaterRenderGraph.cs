#if URP && UNITY_6000_0_OR_NEWER
using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

namespace StylizedWater2
{
    // The legacy passes use global shader state and explicit render target changes.
    // Keep those operations in unsafe graph passes, with all texture dependencies declared.
    internal static class WaterRenderGraph
    {
        private sealed class PassData
        {
            public Action<CommandBuffer> execute;
        }

        internal static void Record(RenderGraph graph, string name, Action<CommandBuffer> execute,
            TextureHandle[] reads = null, TextureHandle[] writes = null,
            TextureHandle globalTexture = default, int globalProperty = 0,
            RendererListHandle rendererList = default)
        {
            using (var builder = graph.AddUnsafePass<PassData>(name, out var data))
            {
                data.execute = execute;
                if (reads != null)
                    foreach (var texture in reads)
                        if (texture.IsValid()) builder.UseTexture(texture, AccessFlags.Read);
                if (writes != null)
                    foreach (var texture in writes)
                        if (texture.IsValid()) builder.UseTexture(texture, AccessFlags.ReadWrite);
                if (rendererList.IsValid()) builder.UseRendererList(rendererList);
                if (globalTexture.IsValid()) builder.SetGlobalTextureAfterPass(globalTexture, globalProperty);
                builder.UseAllGlobalTextures(true);
                builder.AllowGlobalStateModification(true);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc((PassData pass, UnsafeGraphContext context) =>
                    pass.execute(CommandBufferHelpers.GetNativeCommandBuffer(context.cmd)));
            }
        }

        internal static TextureHandle CreateTexture(RenderGraph graph, RenderTextureDescriptor descriptor,
            string name, GraphicsFormat format, int downsample = 1, bool mono = false)
        {
            descriptor.width = Mathf.Max(1, descriptor.width / downsample);
            descriptor.height = Mathf.Max(1, descriptor.height / downsample);
            descriptor.depthBufferBits = 0;
            descriptor.msaaSamples = 1;
            descriptor.bindMS = false;
            descriptor.graphicsFormat = format;
            if (mono)
            {
                descriptor.dimension = TextureDimension.Tex2D;
                descriptor.volumeDepth = 1;
                descriptor.vrUsage = VRTextureUsage.None;
            }
            return UniversalRenderer.CreateRenderGraphTexture(graph, descriptor, name, false,
                FilterMode.Bilinear, TextureWrapMode.Clamp);
        }

        internal static void SetCameraTarget(CommandBuffer cmd, TextureHandle color, TextureHandle depth)
        {
            CoreUtils.SetRenderTarget(cmd, (RTHandle)color, (RTHandle)depth, ClearFlag.None, Color.clear);
        }
    }

    public partial class SetupConstants
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var cameraData = frameData.Get<UniversalCameraData>();
            var lights = frameData.Get<UniversalLightData>();
            bool directional = m_directionalCaustics && lights.mainLightIndex >= 0;
            var projection = Matrix4x4.identity;
            if (directional)
            {
                var light = lights.visibleLights[lights.mainLightIndex];
                directional = light.lightType == LightType.Directional && light.light != null;
                if (directional) projection = Matrix4x4.Rotate(light.light.transform.rotation).inverse;
            }
            bool displacement = settings.displacementPrePassSettings.enable;
            bool reflections = settings.screenSpaceReflectionSettings.enable;
            WaterRenderGraph.Record(graph, "Water shader constants", cmd =>
            {
                CoreUtils.SetKeyword(cmd, DisplacementPrePass.KEYWORD, displacement);
                cmd.SetGlobalInt(_WaterSSREnabled, reflections ? 1 : 0);
                cmd.SetGlobalInt(_WaterDisplacementPrePassAvailable, displacement ? 1 : 0);
                cmd.SetGlobalInt(_EnableDirectionalCaustics, directional ? 1 : 0);
                if (directional)
                {
                    cmd.SetGlobalMatrix(CausticsProjection, projection);
                    NormalReconstruction.SetupProperties(cmd, cameraData);
                }
            });
        }
    }

    public partial class DisplacementPrePass
    {
        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var cameraData = frameData.Get<UniversalCameraData>();
            var renderingData = frameData.Get<UniversalRenderingData>();
            var lights = frameData.Get<UniversalLightData>();
            var drawing = RenderingUtils.CreateDrawingSettings(m_ShaderTagIdList, renderingData, cameraData,
                lights, SortingCriteria.RenderQueue | SortingCriteria.SortingLayer | SortingCriteria.CommonTransparent);
            drawing.perObjectData = PerObjectData.None;
            var list = graph.CreateRendererList(new RendererListParams(renderingData.cullResults, drawing, m_FilteringSettings));
            var descriptor = new RenderTextureDescriptor(resolution, resolution);
            var target = WaterRenderGraph.CreateTexture(graph, descriptor, BufferName, GraphicsFormat.R16_SFloat);
            var camera = cameraData.camera;
            var viewMatrix = cameraData.GetViewMatrix();
            var projectionMatrix = GL.GetGPUProjectionMatrix(cameraData.GetProjectionMatrix(), true);
            var viewport = camera.pixelRect;
            WaterRenderGraph.Record(graph, profilerTag, cmd =>
            {
                CoreUtils.SetRenderTarget(cmd, (RTHandle)target, ClearFlag.Color, targetClearColor);
                cmd.EnableShaderKeyword(KEYWORD);
                SetupProjection(cmd, camera);
                cmd.DrawRendererList(list);
                cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
                cmd.SetGlobalMatrix("UNITY_MATRIX_V", viewMatrix);
                cmd.SetViewport(viewport);
            }, writes: new[] { target }, globalTexture: target, globalProperty: _WaterDisplacementBuffer,
                rendererList: list);
        }
    }
}
#endif
