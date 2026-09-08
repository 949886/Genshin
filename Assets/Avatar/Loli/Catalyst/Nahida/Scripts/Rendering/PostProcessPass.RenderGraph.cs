#if UNITY_6000_0_OR_NEWER
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace Nahida.Rendering
{
    public partial class PostProcessPass
    {
        private sealed class GraphPassData
        {
            public Material material;
            public TextureHandle source, destination, bloom;
            public TextureHandle[] bufferA, bufferB;
        }

        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var camera = frameData.Get<UniversalCameraData>();
            var resources = frameData.Get<UniversalResourceData>();
            if (camera.cameraType == CameraType.Preview || camera.cameraType == CameraType.Reflection ||
                resources.isActiveTargetBackBuffer || _material == null) return;

            var stack = VolumeManager.instance.stack;
            var bloom = stack.GetComponent<BloomVolume>();
            var grading = stack.GetComponent<ColorGradingVolume>();
            if (bloom == null || grading == null || (!bloom.IsActive() && !grading.IsActive())) return;
            _useBloom = bloom.IsActive();
            _downSampleScale = bloom.downSampleScale.value;
            SetupMaterial(bloom, grading, camera.cameraTargetDescriptor.height);

            var source = resources.activeColorTexture;
            var descriptor = graph.GetTextureDesc(source);
            descriptor.name = "Nahida post process";
            descriptor.msaaSamples = MSAASamples.None;
            descriptor.clearBuffer = false;
            var destination = graph.CreateTexture(descriptor);
            TextureHandle[] bufferA = null, bufferB = null;
            var combinedBloom = TextureHandle.nullHandle;
            if (_useBloom)
            {
                // The shader combines exactly four bloom levels.
                int levels = Mathf.Max(4, _iterations);
                bufferA = new TextureHandle[levels];
                bufferB = new TextureHandle[levels];
                descriptor.width = Mathf.Max(1, Mathf.RoundToInt(descriptor.width * _downSampleScale));
                descriptor.height = Mathf.Max(1, Mathf.RoundToInt(descriptor.height * _downSampleScale));
                descriptor.filterMode = FilterMode.Bilinear;
                descriptor.name = "Nahida combined bloom";
                combinedBloom = graph.CreateTexture(descriptor);
                for (int i = 0; i < levels; i++)
                {
                    descriptor.name = $"Nahida bloom A {i}";
                    bufferA[i] = graph.CreateTexture(descriptor);
                    descriptor.name = $"Nahida bloom B {i}";
                    bufferB[i] = graph.CreateTexture(descriptor);
                    descriptor.width = Mathf.Max(1, descriptor.width / 2);
                    descriptor.height = Mathf.Max(1, descriptor.height / 2);
                }
            }
            using (var builder = graph.AddUnsafePass<GraphPassData>(nameof(PostProcessPass), out var data, profilingSampler))
            {
                data.material = _material;
                data.source = source;
                data.destination = destination;
                data.bloom = combinedBloom;
                data.bufferA = bufferA;
                data.bufferB = bufferB;
                builder.UseTexture(source, AccessFlags.Read);
                builder.UseTexture(destination, AccessFlags.Write);
                if (bufferA != null)
                {
                    foreach (var texture in bufferA) builder.UseTexture(texture, AccessFlags.ReadWrite);
                    foreach (var texture in bufferB) builder.UseTexture(texture, AccessFlags.ReadWrite);
                    builder.UseTexture(combinedBloom, AccessFlags.ReadWrite);
                }
                builder.AllowGlobalStateModification(true);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc((GraphPassData pass, UnsafeGraphContext context) =>
                {
                    var cmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);
                    if (pass.bufferA != null)
                    {
                        var a = pass.bufferA;
                        var b = pass.bufferB;
                        BlitGraph(cmd, pass.source, a[0], pass.material, Pass.BloomPrefilter);
                        BlitGraph(cmd, a[0], b[0], pass.material, Pass.BloomHorizontalBlur1x);
                        BlitGraph(cmd, b[0], a[0], pass.material, Pass.BloomVerticalBlur1x);
                        for (int i = 1; i < a.Length; i++)
                        {
                            BlitGraph(cmd, a[i - 1], b[i], pass.material, Pass.BloomHorizontalBlur2x);
                            BlitGraph(cmd, b[i], a[i], pass.material, Pass.BloomVerticalBlur1x);
                        }
                        cmd.SetGlobalTexture("_BloomTextureA", (RTHandle)a[0]);
                        cmd.SetGlobalTexture("_BloomTextureB", (RTHandle)a[1]);
                        cmd.SetGlobalTexture("_BloomTextureC", (RTHandle)a[2]);
                        cmd.SetGlobalTexture("_BloomTextureD", (RTHandle)a[3]);
                        BlitGraph(cmd, a[0], pass.bloom, pass.material, Pass.BloomUpsample);
                        cmd.SetGlobalTexture("_BloomTextureA", (RTHandle)pass.bloom);
                    }
                    BlitGraph(cmd, pass.source, pass.destination, pass.material, Pass.ColorGrading);
                });
            }
            resources.cameraColor = destination;
        }

        private static void BlitGraph(CommandBuffer cmd, TextureHandle source, TextureHandle target, Material material, Pass pass)
        {
            CoreUtils.SetRenderTarget(cmd, (RTHandle)target, ClearFlag.None, Color.clear);
            Blitter.BlitTexture(cmd, source, new Vector4(1, 1, 0, 0), material, (int)pass);
        }
    }
}
#endif
