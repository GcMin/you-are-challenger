# 资源来源与重建

运行资源均来自用户提供的本地文件。没有下载替代角色或用几何占位替换指定模型。

| 运行资源 | 来源 | 处理 |
| --- | --- | --- |
| `assets/characters/challenger.glb` 人物与训练靶 | `LowPolyHuman2.obj` | 约 1.82m 标准尺度；将原有分离低多边形肢体映射到 UAL 的对应骨骼；人物和训练靶使用同一网格，靶放大至 1.35 倍并改为棕橙色 |
| 同 GLB 的大剑 | `MeleeAssets/TwoHandedGreatsword.fbx` | 原始剑网格归一到 1.65m，绑定右手；双臂解析 IK 将握点放在共同可达范围，手肘向外弯曲，两只手使用可辨认的棕色手套材质 |
| `assets/weapons/greatsword.glb` | 同一 FBX | 独立、以握柄为原点的派生资源，供后续武器替换使用；当前角色使用合并蒙皮版本 |
| 待机、跑步、轻击、翻滚、受击、倒地 | `Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb` | 使用 `Sword_Idle`、`Jog_Fwd_Loop`、`Sword_Attack`、`Roll`、`Hit_Chest`、`Death01`，无根运动版本 |
| 重击 | `Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb` | 使用 `Sword_Regular_A` 与 `Sword_Regular_A_Rec`，按前摇/生效/收招三段重定时，并返回大剑待机 |
| 翻滚起身 | UAL1 `Roll` 的末段 | 将 0–25 帧作为滚动主体，25–35 帧作为起身，追加回大剑待机的姿态过渡 |
| Boss 重砸 / 突进 | UAL1 `Sword_Idle` 与双臂 IK 派生姿势 | `boss_slam` 举剑蓄力与下砸；`boss_dash` 前向持剑与伸展，按状态三段采样，最后回到双手站姿 |
| 挥击、命中、受击声音 | `training/feedback_audio.gd` | 本地生成的短合成音，作为原型反馈 |

UAL 资源附带 Quaternius CC0 许可，原始 `License.txt` 保留在源目录。OBJ 和武器 FBX 保留用户原文件，不推断其许可证。OBJ 原本引用的 `LowPolyHuman2.mtl` 未提供，现补充中性材质文件以避免 Godot 原始网格导入报错；游戏 GLB 使用单独配置的材质。

源动作库和武器包目录添加 `.gdignore`，避免 Godot 把整套 Unity/Unreal 动作重复导入。生成后的 GLB 可独立运行，无需打开 Blender 或维持 MCP 连接。

## 重建

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_assets.py
```

重建脚本只更新派生资源，使用独立后台 Blender 场景。不会修改当前打开的 Blender 用户场景。
可编辑的绑定源文件保存在 `assets/source/challenger_source.blend`，该目录已 `.gdignore`；源 `.blend` 不纳入 Git，能够通过脚本重建。

当前绑定针对原 OBJ 的分离肢体结构，保留棱角和节段感；不是通用自动蒙皮器。翻滚时允许左手脱离大剑，起身后双手回到握柄。后续换模型应重新设置源肢体映射与握点。`docs/rig_validation.json` 记录左右手臂蒙皮顶点数量与采样握点误差，构建时有对应断言。
