# World Partition

场景已接入 Blender 生成的 **MeadowWorld**：700 × 700 米、49 个 100 × 100 米的地表区块，
包含草地丘陵、河流、1,152 棵树、岩石、小路、木桥和山坡石柱遗迹。
区块坐标为 `X/Z = -3…3`、`Y = 0`，世界范围为 `X/Z = -300…400`。

停止当前 Play Mode，等脚本编译完成后重新运行 `World Partition.unity`，再点击 **Game** 窗口获取输入焦点。
`MeadowWorldExplorer` 会在运行时将实际游戏相机移到地形上方，并禁用旧的 Cinemachine Brain，避免相机被覆盖。
即使编辑器仍打开着修改前的这个场景，进入 Play Mode 时也会为主相机补上漫游组件。

操作：**W/A/S/D** 移动，**按住鼠标右键** 转动视角，**Q/E** 下降/上升，**Shift** 加速，**Home** 返回初始视角。
这是用于查看大世界的自由飞行相机，接近地面时会自动抬高以避免进入地形内部。
`Player` 现在是随镜头前方移动的分区观察点，高度固定在 `Y0`，因此飞到高空后地面仍会保持加载。
`renderDistance = 3` 在初始位置覆盖全部 49 个地表区块。

模型、prefab、18 个共享 URP 材质和生成清单位于 `Assets/Scenes/WorldPartitions/MeadowWorld/`。
`World Chunks` Addressables 分组使用本地路径并按区块分别打包。
天空、地下和地图边界以外没有地表模型，因此场景的 `fallback` 已留空。

`WorldRenderer` 按玩家位置加载周围 `(2 * renderDistance + 1)^3` 个区块。
`Chunk` 先通过 Addressables 查询 `GameObject` 类型的资源地址，再加载实际存在的 prefab。
缺失的地址使用 `fallback`；未设置 `fallback` 时区块进入 `Empty` 状态，不生成物体。
网络、资源包或目录加载失败仍保留错误诊断。

## 接入区块资源

1. 把每个区块保存为 prefab，并加入 Addressables 分组。
2. **Address 字段**必须为 `Chunk_X{x}_Y{y}_Z{z}`，例如 `Chunk_X-1_Y0_Z2`。
   仅修改 prefab 文件名并不会自动修改已有的 Address。
3. prefab 的几何体使用区块内的局部坐标；加载器将根节点放在
   `(x * chunkSize, y * chunkSize, z * chunkSize)`，不要在模型内重复加入区块的世界偏移。
4. 玩家位置使用向下取整计算区块坐标。例如 `chunkSize = 100` 时，
   `x = -0.1` 属于 `X-1`，`x = -100` 仍属于 `X-1`。
5. 使用已有构建的 Play Mode 或运行打包后的游戏时，更新资源后需要重新构建 Addressables 内容；
   远程分组还需要更新对应的远程目录和资源包。

## 编辑与重新生成

Blender 源文件为 `Tools/WorldPartition/MeadowWorld.blend`，脚本为同目录的 `generate_world.py`。
`.blend` 内每个区块有独立 Collection；`Preview Studio (not exported)` 仅用于渲染总览。
总览图为 `Tools/WorldPartition/MeadowWorld-overview.png`，它是 Blender 渲染，不是 Unity 截图。

从工程根目录在 PowerShell 中重新生成：

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' -b --python Tools/WorldPartition/generate_world.py -- --root . --render
```

随后在 Unity 中执行 `Tools > World Partition > Import Blender Meadow World`，更新材质映射、
prefab、碰撞体和 Addressables 登记。首次交付已经完成导入，无需重复执行。
导入工具会检查实际 FBX 的 100 米尺寸、坐标方向、地形法线和相邻区块边界。
重新生成会覆盖本生成器拥有的 FBX 和 prefab；手工制作的新世界应使用独立目录。

地形采用统一世界坐标采样，边缘使用相同顶点高度与法线。
FBX 采用关闭网格压缩、导入法线和统一材质映射的设置。
地形、石块、树干、木桥和石柱带静态 MeshCollider；水面和树冠不阻挡移动。

## 验证

在 Unity Test Runner 的 PlayMode 中运行 `Luna.World.Tests`。
`WorldStreamingTests` 使用独立的 Addressables 实例和可控制完成时机的资源提供器，不访问远程资源。
覆盖缺失地址、空区块、重复加载、卸载时取消请求、异步旧结果释放、回调中卸载、
负坐标、远距离移动以及组件禁用和重新启用。
`MeadowWorldTests` 通过实际 Addressables 目录加载全部 49 个 prefab，检查材质、碰撞和流式卸载。
`MeadowWorldExplorerTests` 检查旧相机位置修正、视线内地形、真实 W 键输入、转向、升降和观察点高度。
编辑器验证使用 Addressables 的 `Use Asset Database` Play Mode；使用已有构建时需先重建内容。

运行时代码通过 `Luna.World.asmdef` 独立编译；测试程序集仅用于 Test Runner。
测试初始化适配当前项目的 Addressables 2.4.6，升级该包时需核对测试中的内部字段。
