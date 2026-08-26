# JWMV 开发计划：JDK、Maven、Gradle、Kotlin 版本管理与即时切换

## 📋 项目目标

开发一个 Windows 平台下的 CLI 工具，用于管理和切换以下工具的版本，并确保环境变量**立即生效**：
- **JDK (Java Development Kit)** - 通过 Foojay API
- **Maven** - 通过 Maven Central
- **Gradle** - 通过 Gradle Services
- **Kotlin** - 通过 GitHub Releases

---

## ✅ 当前状态评估

### 已完成功能
| 功能模块 | 状态 | 说明 |
|---------|------|------|
| 核心架构 | ✅ | Clean Architecture + DI |
| JDK 支持 | ✅ | Foojay API 集成 |
| Gradle 支持 | ✅ | 版本目录提供 |
| Maven 支持 | ✅ | 版本目录提供 |
| Kotlin 支持 | ✅ | GitHub Releases 集成 |
| 安装/卸载 | ✅ | 带校验和验证 |
| PowerShell 集成 | ✅ | Profile 自动加载 |
| 会话切换 | ✅ | `jwmv use` 输出脚本 |
| 默认设置 | ✅ | `jwmv default` 修改用户环境变量 |
| 项目配置 | ✅ | `.jwmvrc` 文件支持 |
| 自更新 | ✅ | `jwmv selfupdate` |
| 诊断工具 | ✅ | `jwmv doctor` |

### 需要改进的关键点
| 问题 | 影响 | 优先级 |
|------|------|--------|
| 会话切换需要手动执行脚本 | 用户体验不流畅 | 🔴 高 |
| 缺少交互式 TUI | 安装过程不够友好 | 🟡 中 |
| 版本解析不支持通配符 | 灵活性不足 | 🟡 中 |
| 日志系统缺失 | 调试困难 | 🟡 中 |
| 测试覆盖率不足 | 质量风险 | 🟡 中 |

---

## 🎯 核心任务清单

### 阶段一：完善即时切换功能（1-2 周）

#### Task 1.1: 增强 `jwmv use` 命令的自动化
- [ ] **Task 1.1.1**: 检测当前 shell 类型并自动输出对应脚本
  - 文件：`src/Jwmv.Cli/Commands/UseCommand.cs`
  - 改动：当未指定 `--shell` 时，自动检测父进程是 PowerShell 还是 CMD
  - 验收标准：
    ```powershell
    # 在 PowerShell 中直接运行
    jwmv use 21-tem
    # 应自动执行切换，无需额外步骤
    ```

- [ ] **Task 1.1.2**: 实现 CMD 批处理脚本生成
  - 文件：`src/Jwmv.Core/Models/ShellKind.cs`, `src/Jwmv.Infrastructure/Services/SdkVersionManager.cs`
  - 改动：添加 `ShellKind.Cmd` 支持，生成 `.bat` 格式脚本
  - 验收标准：
    ```cmd
    jwmv use 21-tem --shell cmd
    # 输出可在 CMD 中直接执行的批处理命令
    ```

- [ ] **Task 1.1.3**: 优化 PowerShell 脚本执行流程
  - 文件：`src/Jwmv.Infrastructure/Services/SdkVersionManager.cs`
  - 改动：在 `BuildActivationScript` 中添加环境变量广播调用
  - 关键代码：
    ```csharp
    // 在脚本末尾添加
    [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)]
    $envVar = "Environment"
    [void] [System.Windows.Forms.SystemInformation]::UserInteractive
    # 或者调用现有的 EnvironmentBroadcast.Notify()
    ```

#### Task 1.2: 实现环境变量立即生效机制
- [ ] **Task 1.2.1**: 扩展现有 `EnvironmentBroadcast` 类
  - 文件：`src/Jwmv.Infrastructure/Windows/EnvironmentBroadcast.cs`
  - 改动：确保在会话切换时也广播环境变量变化
  - 验收标准：切换后新打开的终端能继承当前选择

- [ ] **Task 1.2.2**: 在 `SdkEnvironmentService` 中添加会话级应用方法
  - 文件：`src/Jwmv.Infrastructure/Windows/SdkEnvironmentService.cs`
  - 新增方法：`ApplySessionAsync(InstalledSdkVersion, CancellationToken)`
  - 功能：
    - 设置进程级环境变量（立即生效）
    - 设置会话级变量（PowerShell 作用域）
    - 触发 WM_SETTINGCHANGE 广播

- [ ] **Task 1.2.3**: 修改 `BuildActivationScript` 确保路径正确更新
  - 文件：`src/Jwmv.Infrastructure/Services/SdkVersionManager.cs`
  - 改动：优化 PATH 更新逻辑，避免重复条目
  - 验收标准：多次切换不会产生 PATH 污染

#### Task 1.3: 创建一键切换命令
- [ ] **Task 1.3.1**: 新增 `jwmv switch` 命令（`use` 的别名增强版）
  - 文件：`src/Jwmv.Cli/Commands/SwitchCommand.cs` (新建)
  - 功能：
    - 自动检测 shell
    - 自动执行切换
    - 显示确认信息
  - 验收标准：
    ```powershell
    jwmv switch 21-tem
    # 立即生效，无需 Invoke-Expression
    java -version  # 显示新版本
    ```

- [ ] **Task 1.3.2**: 为 `switch` 命令添加交互式版本选择
  - 功能：如果不指定版本，显示已安装版本列表供选择
  - UI：使用 Spectre.Console 的选择器

---

### 阶段二：提升用户体验（2-3 周）

#### Task 2.1: 实现交互式 TUI 安装
- [ ] **Task 2.1.1**: 重构 `InstallCommand` 支持交互模式
  - 文件：`src/Jwmv.Cli/Commands/InstallCommand.cs`
  - 改动：
    - 无参数时显示候选者选择菜单
    - 选择候选者后显示版本列表
    - 支持搜索过滤
  - UI 组件：Spectre.Console.SelectionPrompt

- [ ] **Task 2.1.2**: 添加下载进度条优化
  - 文件：`src/Jwmv.Cli/Commands/CommandHelpers.cs`
  - 改动：显示下载速度、剩余时间、百分比

- [ ] **Task 2.1.3**: 实现并行下载多个候选者
  - 改动：`jwmv install java 21-tem gradle 9.5.1 maven 3.9.15`
  - 技术：使用 `Task.WhenAll` 并行下载

#### Task 2.2: 增强版本解析能力
- [ ] **Task 2.2.1**: 支持语义化版本通配符
  - 文件：`src/Jwmv.Core/Utilities/JavaIdentifier.cs`, `SdkIdentifier.cs`
  - 支持格式：
    - `21.x` 或 `21.*` → 最新 21 版本
    - `latest` → 最新版本
    - `lts` → 最新 LTS 版本
    - `>=17 <18` → 版本范围

- [ ] **Task 2.2.2**: 实现智能版本匹配
  - 改动：在 `ResolveBestPackage` 方法中增强逻辑
  - 验收标准：
    ```powershell
    jwmv install java 21      # 安装最新 Java 21
    jwmv install java lts     # 安装最新 LTS
    jwmv install gradle latest # 安装最新 Gradle
    ```

#### Task 2.3: 添加日志系统
- [ ] **Task 2.3.1**: 引入 Microsoft.Extensions.Logging
  - 文件：`src/Jwmv.Cli/Program.cs`, `src/Jwmv.Infrastructure/ServiceCollectionExtensions.cs`
  - 改动：注册 ILoggerFactory，配置 ConsoleLogger

- [ ] **Task 2.3.2**: 在所有服务中添加日志记录
  - 重点：下载、解压、环境变量修改操作
  - 级别：Error/Warn/Info/Debug

- [ ] **Task 2.3.3**: 添加 `--verbose` 全局选项
  - 文件：`src/Jwmv.Cli/Program.cs`
  - 功能：控制日志输出级别

---

### 阶段三：质量保证与文档（1-2 周）

#### Task 3.1: 增加单元测试
- [ ] **Task 3.1.1**: 为核心服务编写测试
  - 文件：`tests/Jwmv.Tests/Services/`
  - 覆盖：
    - `SdkVersionManager.BuildActivationScript`
    - `SdkEnvironmentService.ApplyDefaultAsync`
    - `EnvironmentBroadcast.Notify`

- [ ] **Task 3.1.2**: 为版本解析编写测试
  - 文件：`tests/Jwmv.Tests/Utilities/`
  - 覆盖：
    - `JavaIdentifier.Matches`
    - `SdkIdentifier.Matches`
    - 通配符匹配逻辑

- [ ] **Task 3.1.3**: 集成测试
  - 场景：完整安装→切换→卸载流程
  - 工具：xUnit + 临时目录

#### Task 3.2: 完善文档
- [ ] **Task 3.2.1**: 更新 README.md
  - 添加 `jwmv switch` 使用说明
  - 补充环境变量立即生效的原理说明
  - 添加故障排查章节

- [ ] **Task 3.2.2**: 创建快速入门指南
  - 文件：`docs/QUICKSTART.md` (新建)
  - 内容：5 分钟内上手

- [ ] **Task 3.2.3**: 编写 CONTRIBUTING.md
  - 开发环境搭建
  - 构建和测试流程
  - 代码规范

#### Task 3.3: 设置 CI/CD
- [ ] **Task 3.3.1**: 配置 GitHub Actions
  - 文件：`.github/workflows/ci.yml`
  - 流程：
    - 构建（Windows x64/ARM64）
    - 测试
    - 打包发布

- [ ] **Task 3.3.2**: 添加自动发布流程
  - 触发：Tag 推送
  - 产出：GitHub Release + NuGet + npm

---

## 📅 时间表

| 周次 | 主要任务 | 交付物 |
|------|---------|--------|
| Week 1 | Task 1.1-1.3 (即时切换) | `jwmv switch` 命令，CMD 支持 |
| Week 2 | Task 2.1-2.2 (TUI + 版本解析) | 交互式安装，通配符支持 |
| Week 3 | Task 2.3 (日志) + Task 3.1 (测试) | 完整日志系统，70% 测试覆盖 |
| Week 4 | Task 3.2-3.3 (文档 + CI/CD) | v1.1 发布 |

---

## 🔧 技术实现细节

### 环境变量立即生效原理

```csharp
// 1. 进程级（当前进程立即生效）
Environment.SetEnvironmentVariable("JAVA_HOME", path, EnvironmentVariableTarget.Process);

// 2. 用户级（持久化，新进程继承）
Environment.SetEnvironmentVariable("JAVA_HOME", path, EnvironmentVariableTarget.User);

// 3. 广播通知其他进程
EnvironmentBroadcast.Notify(); 
// 发送 WM_SETTINGCHANGE + "Environment"
```

### PowerShell 脚本示例

```powershell
# BuildActivationScript 生成的脚本
$__jwmvPreviousBin = $env:JWMV_ACTIVE_JAVA_BIN
if ($__jwmvPreviousBin) {
    $env:Path = @($env:Path -split ';' | Where-Object { $_ -and $_ -ne $__jwmvPreviousBin }) -join ';'
}

$env:JAVA_HOME = 'C:\Users\me\.jwmv\candidates\java\21-tem'
$env:JWMV_ACTIVE_JAVA_VERSION = '21-tem'
$env:JWMV_ACTIVE_JAVA_HOME = 'C:\Users\me\.jwmv\candidates\java\21-tem'
$env:JWMV_ACTIVE_JAVA_BIN = 'C:\Users\me\.jwmv\candidates\java\21-tem\bin'
$env:JWMV_ACTIVE_JAVA_SOURCE = 'Session'
$env:Path = 'C:\Users\me\.jwmv\candidates\java\21-tem\bin;' + 
            (@($env:Path -split ';' | Where-Object { $_ -and $_ -ne 'C:\Users\me\.jwmv\candidates\java\21-tem\bin' }) -join ';')

Write-Host 'Activated java 21-tem for this session.' -ForegroundColor Green
```

### CMD 批处理脚本示例

```batch
@echo off
setlocal enabledelayedexpansion

rem 移除旧的 bin 目录
if defined JWMV_ACTIVE_JAVA_BIN (
    set "NEW_PATH="
    for %%A in (%PATH%) do (
        if /i not "%%A"=="%JWMV_ACTIVE_JAVA_BIN%" (
            if defined NEW_PATH (
                set "NEW_PATH=!NEW_PATH!;%%A"
            ) else (
                set "NEW_PATH=%%A"
            )
        )
    )
    set "PATH=%NEW_PATH%"
)

rem 设置新变量
set "JAVA_HOME=C:\Users\me\.jwmv\candidates\java\21-tem"
set "JWMV_ACTIVE_JAVA_VERSION=21-tem"
set "JWMV_ACTIVE_JAVA_HOME=C:\Users\me\.jwmv\candidates\java\21-tem"
set "JWMV_ACTIVE_JAVA_BIN=C:\Users\me\.jwmv\candidates\java\21-tem\bin"
set "JWMV_ACTIVE_JAVA_SOURCE=Session"
set "PATH=C:\Users\me\.jwmv\candidates\java\21-tem\bin;%PATH%"

echo Activated java 21-tem for this session.
```

---

## 📊 成功指标

| 指标 | 目标值 | 测量方式 |
|------|--------|----------|
| 版本切换时间 | < 1 秒 | 基准测试 |
| 环境变量生效延迟 | 即时 | 手动验证 |
| 测试覆盖率 | > 80% | coverlet |
| 支持的候选者 | ≥ 4 个 | java/maven/gradle/kotlin |
| 用户满意度 | > 4.5/5 | GitHub Issues 反馈 |

---

## ⚠️ 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| PowerShell 执行策略限制 | 中 | 高 | 提供 Bypass 脚本指导 |
| 环境变量长度超限 | 低 | 中 | 实现 PATH 压缩算法 |
| 并发切换冲突 | 低 | 中 | 添加文件锁机制 |
| API 变更导致目录失效 | 中 | 高 | 抽象 Catalog Provider 接口 |

---

## 🚀 下一步行动

### 立即开始（今天）
1. ✅ 审查现有 `UseCommand.cs` 和 `SdkVersionManager.cs`
2. ✅ 设计 `SwitchCommand` 接口
3. ✅ 创建 Git 分支：`feature/instant-switch`

### 本周完成
- [ ] 实现 Task 1.1.1-1.1.3（自动 Shell 检测）
- [ ] 实现 Task 1.2.1-1.2.3（环境变量广播）
- [ ] 初步测试切换功能

### 下周完成
- [ ] 实现 Task 1.3（`jwmv switch` 命令）
- [ ] 编写相关测试
- [ ] 更新文档

---

## 📝 附录：相关文件清单

### 需要修改的文件
```
src/Jwmv.Cli/Commands/
├── UseCommand.cs              # 增强自动检测
├── SwitchCommand.cs           # 新建
└── InstallCommand.cs          # 添加交互模式

src/Jwmv.Core/
├── Models/ShellKind.cs        # 添加 Cmd 枚举
├── Abstractions/ISdkEnvironmentService.cs  # 添加 ApplySessionAsync
└── Utilities/
    ├── JavaIdentifier.cs      # 添加通配符支持
    └── SdkIdentifier.cs       # 添加通配符支持

src/Jwmv.Infrastructure/
├── Services/SdkVersionManager.cs         # 添加 BuildCmdScript
├── Windows/
│   ├── SdkEnvironmentService.cs          # 添加 ApplySessionAsync
│   └── EnvironmentBroadcast.cs           # 增强广播
└── ServiceCollectionExtensions.cs        # 注册日志

tests/Jwmv.Tests/
├── Commands/SwitchCommandTests.cs
├── Services/SdkEnvironmentServiceTests.cs
└── Utilities/IdentifierTests.cs
```

### 新建文件
```
docs/
├── QUICKSTART.md
└── TROUBLESHOOTING.md

.github/workflows/
└── ci.yml
```

---

**制定日期**: 2025  
**版本**: v1.0  
**状态**: 待执行
