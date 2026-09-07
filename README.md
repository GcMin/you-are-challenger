# You Are Challenger

Godot 4.7.2 / GDScript；低多边形 3D、第三人称合作擂台 Boss Rush。

## 当前阶段

已实现 **P0-1 角色操控、P0-2 Boss 三招与 P0-3 单人整轮流程**。默认运行平地单人挑战：180 秒时限、两次复活、道具与空投、胜利后自由搜刮、中央两格箱、结束确认与快照往返。真人手感和平衡仍需试玩复验。

本地验证引擎：`4.7.2.stable.official.ed1daf0bf`；Blender：`5.2.0 LTS`。

## 运行

使用 Godot 4.7.2 导入仓库根目录的 `project.godot`，按 **F5**。首次导入需要等待 GLB 资源处理完成。

本机 PowerShell：

```powershell
& 'E:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path 'X:/project/you-are-challenger'
```

| 输入 | 功能 |
| --- | --- |
| WASD / 鼠标 | 相对镜头移动 / 旋转镜头 |
| 左键 / 右键 | 单段轻击 / 消耗精力的重击 |
| 空格 | 移动方向翻滚；无方向时向角色前方 |
| Enter | 准备时开始；胜利搜刮时打开结束确认 |
| E | 拾取附近物品 / 打开中央箱 |
| 1 / 2 | 使用对应道具栏 |
| Shift+1 / Shift+2 | 满栏时交换附近道具，旧物落地 |
| R | 准备或结果阶段开始新一轮 |
| F9 / F10 | 搜刮时保存 / 确认还原箱内测试快照 |
| F1 | 显示实际攻击查询体积 |
| Esc | 暂停、释放鼠标；再次按下继续 |

轻击消耗 10 精力，重击消耗 20；忙碌期间的额外点击不会排队。翻滚消耗 25 精力，滚动 0.55 秒后有 **0.05 秒起身收势**；仅 0.08–0.28 秒无敌。精力不足时仍能移动并等待恢复。

原 `training/training_ground.tscn`（静态训练靶，含镜头测试墙）与 `boss/boss_arena.tscn`（Boss 对练）保留，可从编辑器单独运行；这两个练习场之间仍用 F2 切换。

## 开发与验证

- [P0-1 实现与验收说明](docs/p0_1_implementation.md)
- [P0-2 Boss 实现与验收说明](docs/p0_2_implementation.md)
- [P0-3 流程、操作与验收说明](docs/p0_3_implementation.md)
- [P0-3 独立验收问题修复与默认启动回归](docs/p0_3_qa_fixes.md)
- [资源来源与重建](docs/assets.md)
- 调参入口：`player/default_tuning.tres`，默认数值定义在 `player/combat_tuning.gd`。
- Boss 调参入口：`boss/default_tuning.tres`，默认数值定义在 `boss/boss_tuning.gd`。
- 回归测试：`tests/test_p0_1.gd`；渲染取样：`tests/capture_scene.gd`。测试输出存放于被 Git 忽略的 `test_output/`。

```powershell
# 包含真实鼠标与镜头的集成检查，请保持游戏测试窗口获得焦点。
& 'E:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/test_p0_1.gd
```

## 策划与开发文档

- [Excel 策划与验收台账](you_are_challenger_P0_design.xlsx)：已更新实际修改、参数与 P0-1 至 P0-3 验收。自动检查和真人试玩分别记录，未测项保留。
- Excel 内区分「用户确认」「策划建议」「验证默认」「后续阶段」，建议不等于用户最终确认。
- 数值均为初始测试参数，不代表已经验证的平衡结果。

## 最新规则

共享继承箱仅在战斗胜利后出现在场地中央。击败 Boss 后允许自由搜刮，不限制战后拾取。箱子容量为开局玩家数 × 2；角色携带一把武器、两个道具，无弹药系统。

完整方向保留多人挑战者交接与救援、外围搜集、单人整轮两次复活、空投、限时、战前赌约、积分金币和隐藏 Boss。当前单人验证版不以多人、第二只 Boss、隐藏关或完整局外成长为交付前提。
