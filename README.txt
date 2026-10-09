Enemy HP HUD+ 1.7.1 / BSL v18+

1.7.1 坐标修复 / Projection fix
- 每次投影匹配当前视角，不再使用相机列表第一项或跨帧、跨局缓存相机。
  Match the current view for each projection; remove first-camera selection and retained camera handles.
- 使用与 HUD 一致的视口尺寸，无效坐标隐藏，并记录投影状态供诊断。
  Use the HUD viewport, hide invalid coordinates and report projection status for diagnosis.
- 保留独立 Ping/攻击血条、部位血条及击杀判断。未改变哨戒炮伤害归属触发规则。
  Preserve independent targets, part bars and death rules, including existing sentry-credit triggers.
- 修复已知定位缺陷；游戏内验证仍待进行，尚不能确认覆盖所有间歇失效情况。
  Addresses known projection defects; live validation of intermittent failures is still pending.

1.7.0 更新 / What's new
- Ping 标记与攻击触发分为两套独立血条。Ping A 后攻击 B，两只怪物的血条可同时显示。
  Ping and damage-triggered HUDs are independent. Ping enemy A and hit enemy B to show both.
- 更换攻击目标、攻击血条超时或击杀，不会覆盖或清除 Ping 血条；两套部位显示及淡出独立。
  Damage retargeting, expiry and kills do not replace the ping HUD. Part rows and fades are independent.
- Ping 与攻击同一只怪时只显示一条；取消 Ping 后，仍在持续时间内的攻击血条可继续显示。
  Show one card for a shared enemy. Cancelling its ping reveals the damage HUD if its timer is still active.
- 关闭自动显示或提高自动血量阈值只影响攻击血条，手动 Ping 不受限制。
  Auto-display and HP-threshold settings affect only damage-triggered cards; manual pings bypass them.
- 沿用 BSL v18+、Mod Options Menu v1.2+，以及默认关闭的多部位模式、缩放和不透明度设置。
  Retains BSL v18+, Mod Options Menu v1.2+, optional multi-part mode (default off), scale and opacity.
- 已通过双目标和原有行为的离线回归；尚未进行本版本游戏内验证。
  Dual-target and existing-behaviour offline regression checks passed; live testing is pending.

1.6.1 发布 / Release
- 保留 1.6.0 的全部功能：“显示多个部位血条”默认关闭，开启后最多显示三个部位。
  Includes all 1.6.0 features. Multiple part bars remain off by default; enable for up to three parts.
- 标准 Mod 安装包：ZIP 根目录包含 manifest.json 和 Addon，可直接导入 HD2 Arsenal。
  Standard mod package: manifest.json and Addon are at the ZIP root. Import directly into HD2 Arsenal.
- 需要单独安装 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2+。
  Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2+, installed separately.
- 菜单选项变暗的修复属于 Mod Options Menu，需单独更新该依赖；本包仅更新 Enemy HP HUD+。
  Dim selector styling is fixed in a separate Mod Options Menu update. This package updates Enemy HP HUD+ only.
- 已通过 HUD 离线回归测试。实际游戏效果仍需实测。
  HUD offline regression tests passed. Live gameplay validation is still required.

1.6.0 更新 / What's new
- 新增“显示多个部位血条 / Show multiple part bars”，默认关闭，只显示最近受伤的一个部位。
  Off by default: show only the most recently damaged part.
- 开启后最多显示三个部位，FATAL 优先，同组按最近受伤时间排序；各部位独立过期。
  Enable to retain up to three parts, fatal first then newest hit, with independent expiry.
- 开关始终可选；实际展示仍需开启“大型单位显示部位血量”，敌人最大总 HP >= 775。
  The option is always selectable; part HP display must also be on and enemy max HP must be >= 775.
- 按 APPLY 生效并保存；关闭多部位显示会立即收起多余血条。cfg 回退：multi_parts=0。
  APPLY saves the setting; turning it off immediately reduces the display to one part.

1.5.0 更新 / What's new
- 菜单新增 HUD 缩放 / HUD Scale：0.50–2.00，步长 0.05，默认 1.00。
- 菜单新增 HUD 不透明度 / HUD Opacity (%)：0–100%，步长 5%，默认 100%。
  0% 完全透明，100% 保持原有显示强度；主血条、部位血条、文字、描边和淡出同步调整。
  Scale all bars and text together. Opacity 0% hides everything; 100% keeps the original appearance.
- 按 APPLY 后生效并保存；沿用中英文自动切换。初次注册缩放和不透明度时继承 cfg 值，
  已保存的菜单值优先。菜单开关不变，缩放/透明度不改变目标选择和死亡判定。

1.4.0 更新 / What's new
- 同一敌人最多同时显示三个受伤部位，攻击新部位不会立即清掉之前的部位。
  Retain up to three damaged parts of the same enemy instead of replacing the previous part on each hit.
- FATAL（致死属性）优先；同组按最近受伤时间从新到旧排列，最优先的靠近主血条。
  Fatal parts first, then newest hit first within each group. The first row sits closest to the main HP bar.
- 同次采样内多个部位受伤会同时记录；时间相同时按部位编号排序，不推测逐发顺序。
  Capture all part drops in a sample; tied hit times use part index for stable ordering.
- 每个部位独立续时和过期（默认 3 秒）；超过三项按上述优先级保留，队友伤害不续时。
  Each part has its own timeout (3 seconds by default); keep the highest-priority three. Other players do not renew it.

1.3.1 更新 / What's new
- 菜单名称、说明及阈值选项跟随游戏的“文字语言”：简体/繁体中文均显示中文，
  其他语言或无法读取时显示英文。更改文字语言后重新打开 Esc 菜单即可刷新。
  Menu labels, descriptions and choices use Chinese for a Chinese game Text Language,
  and English otherwise. Reopen the escape menu after changing Text Language.
- 使用 Mod Options Menu 观察到的游戏语言，不使用系统语言、Steam 语言或翻译包强制语言。
  保留原有三个设置及其保存值，不再中英混排；未改变原生菜单的行颜色。

1.3.0 更新 / What's new
- 最低依赖 BSL v18；菜单依赖 CowboyBingus Mod Options Menu v1.2+，两者均单独安装。
  Requires Bingus Shared Loader v18+. Install Mod Options Menu v1.2+ for in-game settings.
- 菜单位置：Esc > MODS > Enemy HP HUD+。按 APPLY 后生效并保存，无需重启。
  Open Esc > MODS > Enemy HP HUD+, then press APPLY to apply and save changes.
- 造成伤害自动显示血条 / Auto HP on damage：默认开启；关闭后仍可手动标记查看。
- 自动显示血条阈值 / Auto HP threshold：默认“全部 / All”；另可选
  “中型单位 (HP 500+) / Medium”或“重型单位 (HP 1000+) / Heavy”。
  按最大总血量判断，包含 500 / 1000 边界；残血仍显示，手动标记不受筛选限制。
  Filter automatic HUD by maximum total HP: all, >= 500, or >= 1000. Manual pings bypass it.
- 大型单位显示部位血量 / Large enemy part HP：默认开启，沿用最大总血量 >= 775 的规则。
  Enabled by default; part details require maximum total HP >= 775.
- 菜单保存值优先于 cfg 中对应的选项；菜单缺失或注册失败时使用 cfg/默认值。
  Saved menu settings take priority; cfg/defaults remain the fallback if the menu is unavailable.
- 菜单值由 Mod Options Menu 保存在
  %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\ModOptionsMenu.values。
  本 mod 不自行写入该文件，不修改其他 mod 的选项。

1.2.0 更新 / What's new
- 主血条下新增独立琥珀色部位血条，显示最近受伤部位的名称、当前/最大 HP、剩余百分比。
- 仅最大总血量 >= 775 的敌人显示部位信息及血条；当前血量降到 775 以下仍显示。
  Enemies with maximum total HP >= 775 show part details and bars, even after current HP falls below 775.
  最大总血量低于 775 时仅显示主血条；手动标记和攻击自动展示均遵循此规则。
- 名称来自该敌人实时 HealthComponentData 中的 zone_name 哈希，与已知原生名称匹配。
  不确定名称用 PART 01..38（游戏零起始槽位 0..37），不按血量猜头/腿，不推测左右。
- FATAL 来自 causes_death_on_death；DOWN 来自 causes_downed_on_death。
  这些是配置属性，不是已死亡/已破坏状态。没有 FATAL 也可能通过主血量传递造成击杀。
- 最大 HP 来自该部位的正数配置值，不是首次采样血量。共享主血池（配置 -1）、未知上限、
  当前血量超过配置上限或读数验证失败时仅显示当前 HP；共享池额外标注 SHARED。
- 此原型尚未解析 HealthManager 的实例专属配置表。当存在任何实例配置副本时，保守地
  停用本次部位元数据展示（名称回退编号、无标签/百分比/部位条），仍显示当前 HP。
  后续可按实体解析覆盖配置以提高覆盖率；不能将共享类配置默认为每个实例的准确上限。
- 每轮采样记录下降的部位池；不是逐发精确命中部位。爆炸、关联部位伤害传递、多人
  集火可能令多个池同时变化。最多保留三个受伤部位，不是列出全身所有弱点。
- 主血量不变、只有部位血量下降时也可触发自动显示，仍受 ui4 最后伤害归属局限影响。
- 部位默认显示 3 秒，本地归属部位伤害续时；队友对已显示部位的伤害更新数值但不续时。
- 部位归零显示空条/0 HP，不标记 DESTROYED；尚未接入独立的部位破坏状态。
- ELIMINATED 仅由独立健康记录 life state == 2 确认。主血量归零、倒地（state 1）、
  部位归零、FATAL 标记或目标消失本身都不是确认死亡。若死亡状态在采样间消失，可能
  漏掉击杀动画；未确认的消失直接隐藏，已确认的死亡继续完成淡出。
- part_hud=0 关闭部位展示；auto_damage=0 时仅为手动标记目标显示。选中目标仍轮询
  死亡状态，即使关闭自动显示也不凭主血量或消失猜测击杀。
- 负值/无效部位血量不显示。房主/客机同步、名称、血条比例与真实部位破坏效果尚待实测。
- 只支持下述构建，原版构建检查保留；无新增钩子、内存写入或 HD2Runtime 运行依赖。
- 测试环境此前有退出游戏时崩溃的报告，原因未确定，本原型未修复该问题。

ui4 新功能：观察到主血量下降、且游戏把这次伤害记在本地玩家名下时，自动显示该敌人的
HUD。默认持续 3 秒，后续伤害续时，确认击杀后沿用 ELIMINATED 和 1.5 秒淡出。
手动标记与攻击自动显示各保留一个独立目标；同一只怪去重。范围伤害优先保持当前攻击目标，否则选择本次
掉血最多的敌人。使用游戏敌人标记分类过滤玩家/道具；未知分类不自动显示。
读取约每 125 毫秒进行一次，批量读取健康数组；进入新世界、重新获取本地玩家或
读取中断后先建立基线，不把此前已经发生的伤害误当作新命中。
无需安装 HD2Runtime；当前版要求 BSL v18 / API 1 和独立菜单依赖。
本 mod 的血量读取没有增加原生钩子或游戏内存写入。

自动触发的限制
- 这是血量轮询，不是逐发命中事件。挡弹不会触发；关闭 part_hud 时只扣部位血量也不会触发。
- 多人集火只保留最后伤害归属，可能漏掉你的伤害；旧归属残留可能把后来的无归属伤害
  算到你身上。当前不能完全消除这两种情况。
- 地雷、持续伤害、战备等只要被游戏记为本地玩家伤害，也可能触发。
- 初次采样前已发生的伤害、两次采样间直接消失的秒杀目标可能漏掉。
- 单人、房主、加入他人房间及实际性能仍需实测；只读布局核对不是命中功能实测。

ui3 修复：标记消失时先隐藏血条，保留最多 0.15 秒以确认最终血量，避免死亡提示
被标记清理提前跳过。确认死亡后在最后可见位置播放 1.5 秒 ELIMINATED 和淡出，
不再依赖怪物尸体或标记继续存在。每个目标独立计时；手动取消存活目标不显示死亡。
已补充真实标记控制、更新和绘制组合测试，覆盖连续击杀、标记先消失、尸体消失、
血量延迟一帧、取消标记、读数暂不可用、菜单、新目标切换及世界切换。

ui2 修复：不再跨帧缓存原生 IdString64 字体/材质对象，改为保存十六进制字符串，
在每次原生 GUI 调用时重新生成临时 ID。ui1 在标记敌人后出现了字体绘制空指针崩溃。
新增临时内存池回收的回归测试；空标签直接返回零宽度；日志记录字体绑定与首次绘制。
此修复仍需要游戏内复测，旧 ui1 测试包不应继续使用。

基于你提供的 Enemy HP 1.1.2，参考 DDRK1NG 的 HD2 HUD+ 0.1.13 Integrated 风格。
显示原生字体的当前血量、较淡的最大血量和百分比，下方是带细描边的血条。
正常血量为米白色，25% 及以下为暖红色；左端保留原标记分类的颜色。
掉血时有短暂残影，击杀显示 ELIMINATED 并淡出。没有大块底板。

安装
1. 安装 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2+：
   https://github.com/CowboyBingus/BingusSharedLoader/releases
   https://github.com/CowboyBingus/ModOptionsMenu/releases
   本 ZIP 不捆绑 Loader 或菜单；已有符合要求的版本可继续使用。
   如使用 Vanilla Plus Megapack 中的 Mod Options Menu 选项，不要重复安装独立菜单包。
2. 在管理器中禁用/移除旧 Enemy HP 或 Enemy HP HUD+，然后导入此 ZIP，启用并部署。
   两者使用相同资源和 GUID；这是替换包，只启用一个。
3. HUD+ 可以继续使用；此包不携带 boot 或 HUD+ 的资源。
4. 需要回退时，禁用此包，重新启用此前备份的版本并部署。

兼容范围
- 沿用原版的游戏构建检查：Steam build 25480438，游戏版本 1.8.46015.0。
  不支持的构建仍自动停用。新增伤害读取只支持同一构建，没有扩大版本支持范围。
- 本人实体标记和生命值的底层读取沿用原版；ui3 调整标记丢失与死亡提示的先后处理。
- 不包含/修改 Bingus Shared Loader，也不要求安装 HUD+。
- 工作区 BingusSharedLoader 源码已同步官方 v18（3d7e3a1），保留 v15 引入的发现接口。
  源码更新不等于安装包已部署；Loader 仍须单独安装。
- 本包已通过官方 v18 启动、v15/v17 停用检查，以及菜单 API 的离线测试。
  菜单实际布局和游戏内最终效果仍待验证。
- 手动标记和攻击自动显示并存；右侧布局未加入。
- macOS 上只能离线验证绘制调用、打包结构和 Lua 语法，不能验证 Windows 游戏的实际渲染。

设置（手动创建或编辑，不覆盖已有设置）
%LOCALAPPDATA%\Hd2EnemyHp\enemy_hp.cfg

offset=-40
scale=1
opacity=100
width=172
auto_damage=1
auto_min_hp=0
damage_duration=3
part_hud=1

offset：原有像素偏移，负数向下；范围 -400 到 400。
scale：UI 大小乘数，0.5 到 2，默认 1。
opacity：不透明度百分比，0 到 100，默认 100，保留原有风格。
width：血条基准宽度，120 到 320，默认 172；数字过长时自动加宽。
auto_damage：1 开启攻击自动显示（默认），0 关闭后仅保留手动标记。
auto_min_hp：自动展示所需的最大总血量，允许 0（全部）、500、1000，默认 0。
part_hud：1 开启大型单位的部位血量（默认），0 关闭；大型单位阈值固定为最大 HP 775。
auto_damage、auto_min_hp、part_hud、scale、opacity 在菜单可用时由菜单管理，
cfg 只作后备；其他选项继续读取 cfg。
damage_duration：最后一次观察到本地归属伤害后的显示秒数，0.5 到 10，默认 3。
UI 大小按 min(屏幕宽/1920, 屏幕高/1080) 缩放，并乘以 scale。
此版不自动读取游戏的 HUD Scale 设置；可用 scale 手动匹配 HUD+。
修改 cfg 后重启游戏；菜单设置按 APPLY 后即时生效。日志位置保持原版不变。

游戏内验证建议
- Ping 一只敌人，再射击另一只，检查两条血条并存；停止攻击约 3 秒后，只收起攻击血条。
- 再测试切换攻击目标、连续击杀、范围伤害，以及队友独自攻击时是否误触发。
- 分别核对单人、房主、加入别人房间；留意多人集火和无归属持续伤害的已知限制。
- 标记一个敌人并伤害它，检查血量、百分比和血条一致，掉血残影正常消退。
- 取消标记、打开菜单、转身到目标背后，检查 UI 隐藏。
- 击杀目标、切换目标、返回飞船再部署，检查没有旧 UI 残留。
- 与 HUD+ 和 Loader 一起启用，并测试你实际使用的分辨率和 HUD Scale。

工作目录
unpacked/：两个原始 mod 的完整解包资源、Lua 源码和带 SHA-256 的清单。
src/presentation.lua：独立 UI 实现。
src/update.lua：目标生命周期与死亡提示处理。
src/damage_reader.lua：有边界检查的只读健康/归属数据适配器。
src/damage_detector.lua：血量变化、本地玩家归属和目标选择。
src/damage_target.lua：共享采样、独立 Ping 部位事件和自动 HUD 续时。
src/part_metadata.lua：有边界和身份复核的部位配置只读解析。
src/part_names.lua：已知原生名称哈希，不包含推测的 Wiki 部位名称。
scripts/preview_parts.py：实际绘制调用的布局示意，示例数值和替代字体。
scripts/build.py：保留原版读取逻辑，替换绘制层，生成补丁和 ZIP。
build/enemy_hp.lua：完整生成后的 mod 源码。
build/ui-changes.diff：相对原版的修改内容。
build/build-report.json：构建哈希；in_game_verified=false。
dependencies.json：BSL v18、Mod Options Menu 的版本/API 和固定测试源码提交。
src/settings.lua：五个菜单选项与存储值的适配，不包含菜单本身。

构建：python3 scripts/build.py
离线测试：需要 Python 的 lupa 包，执行 python3 tests/verify.py。

源码仓库
- 版本管理包含 src、scripts、tests、依赖声明、配置示例及调研文档。
- 构建输入需自行放在同级目录：../Enemy HP 1.1.2/、../HD2 HUD Plus 0.1.13/。
  测试还需要 ../BingusSharedLoader/，版本见 dependencies.json。
  菜单集成测试还需要将 https://github.com/CowboyBingus/ModOptionsMenu 克隆至
  research/vendor/ModOptionsMenu，并检出 dependencies.json 指定的 commit。
- build、dist、unpacked、preview 和 research/vendor 是本地生成或外部依赖目录，
  不纳入 Git；原始 mod、游戏程序、崩溃转储和本机部署记录也不纳入源码提交。

此包为本地修改测试版，原作者与参考来源见 THIRD_PARTY.txt。
