# TinyRecorder 系统与本地化说明

## 项目目标

TinyRecorder 是 macOS 原生键鼠宏录制与回放工具。用户可以录制操作、编辑事件、设置循环与速度，并通过全局快捷键执行宏。本次增加简体中文界面，同时保留英文及既有宏文件兼容性。

## 结构与职责

- `Sources/TinyRecorder/main.swift`：图形界面入口，以及 `--play`、`--convert` 命令行模式。
- `AppDelegate.swift`、`MainWindowController.swift`：应用生命周期、系统菜单、主窗口和设置窗口。
- `MenuBarController.swift`：协调录制、回放、宏库、权限与窗口操作。
- `Recorder.swift`、`RecordingKeyboardFilter.swift`：捕获键鼠事件并过滤控制快捷键。
- `Player.swift`、`PlaybackInputMonitor.swift`、`PlaybackCancellation.swift`：按时间线回放、检测用户输入并中断，以及释放仍按下的键鼠状态。
- `RecordedEvent.swift`：事件模型与导入数据的数值范围规范化。
- `MacroLibrary.swift`：宏元数据、筛选、原子保存和本地文件访问权限。
- `MacroImport.swift`、`TextMacroFormat.swift`：TinyTask、文本及原生宏格式转换。
- `PopoverContentView.swift`、`MacroEditor.swift`：宏库、设置、编辑器与相关弹窗。
- `WelcomeWindow.swift`、`RecordingHUD.swift`、`ActivityCenterView.swift`、`QuickRunPalette.swift`：引导、录制面板、进度和快速运行。
- `Localization.swift`：AppKit 与 SwiftUI 共用的翻译资源读取入口。
- `Resources/en.lproj`、`Resources/zh-Hans.lproj`：英文和简体中文资源。
- `Tests/TinyRecorderTests`：事件编辑、输入过滤、回放中断、格式转换与本地化测试。

## 核心数据流

1. 用户启动录制后，`Recorder` 捕获事件并在内存中维护时间线。
2. 控制器将事件及名称、循环次数、速度等信息保存到 `MacroLibrary`。
3. 编辑器修改事件；保存时由宏库写入本地 JSON。
4. 回放时，`Player` 按事件时间和速度模拟输入；手动输入或停止操作会取消回放。
5. 导入、导出沿用既有 JSON、TinyTask 和文本格式；本次未更改格式版本。

## 语言选择与资源

语言跟随 macOS 的首选语言，支持系统设置中的单独应用语言选择。更改后重新启动应用。未支持的语言回退到英文，不另存应用内语言开关。

- `L10n.text` 用于普通文案和格式化文案。插值通过格式参数传入，不把用户输入作为格式字符串。
- `L10n.count` 使用 `Localizable.stringsdict`，处理数量相关文案。单复数规则按界面语言选择，避免中文地区设置导致英文界面的单数错误。
- `Localizable.strings` 保存普通翻译，英文句子作为键。
- `InfoPlist.strings` 翻译系统权限说明。
- 宏名称、用户标签、备注、SF Symbol 标识、持久化颜色名称、快捷键代码及宏文件命令不参与翻译。
- 颜色只翻译显示标签；已保存的 `Red` 等值保持原样。
- 已保存宏的名称不随语言变化自动改写；新建宏的默认名称使用当前语言。
- 开发日志和命令行外层诊断仍以英文为主；与图形界面共用的导入错误会本地化。

## 构建路径

SwiftPM 在 `Package.swift` 声明默认语言和资源。`build.sh` 将生成的资源 bundle 放进应用的 `Contents/Resources`，并复制权限说明。资源加载优先查找应用内的 bundle，使应用移动到其他位置后仍可运行。

Xcode 使用现有文件系统同步分组编译源码并收集语言资源；此路径直接从主应用 bundle 查找翻译。

`Info.plist` 显式声明支持 `en` 和 `zh-Hans`。没有新增第三方依赖。

## 验证方式

- `swift test`：包含翻译键与占位符一致性、中英文文案、格式参数、0/1/多个数量和宏格式兼容性测试。
- `xcodebuild -project TinyRecorder.xcodeproj -scheme TinyRecorder -configuration Debug CODE_SIGNING_ALLOWED=NO build`：验证原生 Xcode 构建。
- 使用 `TINYRECORDER_INSTALL_DIR` 指定单独输出目录运行 `build.sh`，避免覆盖已有应用。
- 打包后通过 `--convert` 和 `-AppleLanguages '(zh-Hans)'` / `'(en)'` / `'(ja)'` 检查中文、英文及英文回退。
- 为验证移动后不依赖源码目录，可暂时移走构建目录中的资源 bundle，执行打包应用的转换命令，随后恢复构建资源。

## 本次变更与维护约定

原有界面直接嵌入英文；现在主窗口、系统菜单、设置、编辑器、权限引导、状态提示和辅助功能标签使用翻译资源。录制、回放、权限申请和宏持久化机制未改变。

添加文案时同步更新两个语言目录；不要通过拼接英文复数后缀构造数量文案。新的文件格式关键字和配置键不应传入本地化函数。

目前仅支持英文和简体中文。系统生成的错误描述可能由系统语言决定。新增翻译仍需注意长文本在最小窗口尺寸下的布局。完整键鼠录制与回放需要用户授予辅助功能和输入监控权限，单元测试不会替用户授权。
