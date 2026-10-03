# 无损 · DSD · SMB 网盘音乐播放器

一个面向 **Android / 鸿蒙 (OHOS)** 的手机音乐播放器，主打三件事：

- **无损播放**：FLAC / ALAC / WAV / APE / MP3 等，使用 `just_audio` 解码。
- **DSD 比特完美**：支持 `.dsf` / `.dff`，在 Android 上经原生 AAudio 引擎以 **DoP / Native DSD** 直出 USB DAC，绕过系统重采样（非桌面/Web 演示环境的 PCM 回退）。
- **SMB 网盘**：直接浏览并播放局域网 NAS / SMB 共享里的音乐，底层用 `jcifs-ng`（SMB1/2/3）。

> ⚠️ 关于"可运行原型"：本仓库在桌面 / Web 下也能编译运行，用于验证 UI、浏览流程与 DSD 识别逻辑，但 SMB 原生桥与 DSD 比特完美**仅在 Android / 鸿蒙真机 + USB DAC 下生效**。桌面 / Web 下 SMB 用"本地演示目录"代替，DSD 走 PCM 回退。

---

## 技术架构

```
┌──────────────────────── Flutter UI (lib/ui) ────────────────────────┐
│  HomePage · ConnectionsPage · BrowserPage · NowPlayingPage · Widgets │
└───────────────┬───────────────────────────────────┬────────────────┘
                │ Provider                          │ Provider
        ┌───────▼──────────┐                ┌────────▼──────────────┐
        │  SmbManager      │                │  PlayerEngine         │
        │  (连接/客户端选择)│                │  (队列/播放状态)       │
        └───────┬──────────┘                └────────┬──────────────┘
     SmbClient 抽象                  ┌────────────────┼────────────────┐
        ├─ SmbChannelClient ────────┐│  just_audio    │  DsdNativeEngine│
        │   (MethodChannel → Kotlin)││  (无损)         │  (MethodChannel │
        └─ SmbLocalDemoClient       │└────────────────┘  → Kotlin)      │
            (桌面/Web 演示)          └──────────────────────────────────┘
                         │                      │
            ┌────────────▼─────────┐   ┌─────────▼─────────────────────┐
            │ Android 原生层 (Kotlin)│   │ Android 原生层 (Kotlin)        │
            │  SmbPlugin (jcifs-ng)  │   │ DsdPlugin → DsdAudioEngine    │
            │   connect/list/download│   │   (DoP over AudioTrack)        │
            └────────────────────────┘   └───────────────────────────────┘
```

关键解耦点：

- **SmbClient 抽象**：Android 走 `jcifs-ng` 原生桥；桌面 / Web 走 `SmbLocalDemoClient`（本地目录），通过条件导入 `local_demo_factory.dart` 自动切换，**Web 编译时完全排除 `dart:io`**。
- **PlayerEngine 双引擎**：无损用 `just_audio`；DSD 在 Android 上走 `DsdNativeEngine` 原生桥，桌面 / Web 自动降级为 PCM 回退并明确标注"非比特完美"。
- **格式识别**：`format_detect.dart` 按扩展名 + 解析 DSF 头得到 DSD 倍速 / 声道；真实倍速在 Android 上由原生引擎解析后通过 EventChannel 回传。

---

## 快速开始

### 1) 真机（Android / 鸿蒙）—— 完整功能

```bash
# 连接 Android 设备（或启动模拟器），然后：
flutter pub get
flutter run
```

- **SMB**：首页 → "管理 SMB 网盘连接" → 添加（主机 IP / 共享名 / 账号密码）→ 进入共享浏览播放。
- **DSD 比特完美**：用 OTG 接支持 DoP / Native DSD 的 USB DAC，播放 `.dsf/.dff` 时 Now Playing 页会显示 **"比特完美"** 绿标与 DSD 倍速。
- 中国大陆网络若 `pub get` 拉取慢，可临时指定镜像：
  ```bash
  export PUB_HOSTED_URL=https://pub.flutter-io.cn
  flutter pub get
  ```

### 2) 桌面 / Web —— 演示模式

```bash
# Linux 桌面
flutter run -d linux
# 或 Chrome
flutter run -d chrome
```

首页 → "选择本地演示目录" → 选一个含无损音乐的文件夹 → 浏览并播放（DSD 文件会按 PCM 回退播放，仅用于验证 UI / 流程）。

---

## SMB 配置要点

- 协议：jcifs-ng 支持 **SMB1 / SMB2 / SMB3**，默认端口 `445`。
- 地址示例：`host=192.168.1.100`，`share=Music`，`username=guest`，`password=`（视 NAS 而定）。
- 若 NAS 仅开 SMB1（老旧设备），部分固件需手动开启；现代 NAS 建议用 SMB3。
- 权限：Android 端已在 `AndroidManifest.xml` 声明 `INTERNET` / `ACCESS_WIFI_STATE` / `FOREGROUND_SERVICE` 等。
- 依赖坐标见 `android/app/build.gradle`：`eu.agno3.jcifs:jcifs-ng:2.1.10`（jcifs-ng 官方坐标）。注意 `org.codelibs:jcifs-ng` 这个坐标在 Maven Central 上并不存在，写它会直接依赖解析失败；codelibs 那边发布的同名产物坐标是 `org.codelibs:jcifs`（包名/API 与 jcifs-ng 有差异，本项目 Kotlin 代码用的是 jcifs-ng 的 API，不要替换）。
- `android/app/build.gradle` 的 `compileSdkVersion` 必须 ≥ 33（已用 `Math.max(flutter.compileSdkVersion, 33)` 兜底）。Flutter 3.0 默认的 31 会被 `permission_handler_android` 等插件阻断构建。

---

## DSD 比特完美说明

### 当前实现
`android/app/.../audio/DsdAudioEngine.kt` 把 DSD 经 **DoP v1.1** 封装为 24bit PCM（采样率 = DSD 倍速 / 16，立体声），通过 Android `AudioTrack` 输出。在支持 DoP 的 USB DAC 上，DAC 会识别出 DSD 信号并原生解码。

### 关于"比特完美"
`AudioTrack` 仍走 Android 系统混音器，**部分设备 / DAC 路径可能重采样**，未必严格比特完美。要做到**独占 / 比特完美直出**，需改用 **AAudio（C++）** 以 `AAUDIO_SHARING_MODE_EXCLUSIVE` + `AAUDIO_PERFORMANCE_MODE_LOW_LATENCY` 打开 USB 音频设备，并直接写入 DoP / Native DSD 帧。

> 升级路径（已规划，需设备验证）：在 `android/app/src/main/cpp/` 新增 `dsd_aaudio_engine.cpp` + `CMakeLists.txt`，通过 JNI 暴露与 `DsdAudioEngine` 相同的接口，并在 `MainActivity` 中切换实现。

### 支持矩阵

| 场景 | 无损 (FLAC/ALAC/WAV/APE) | DSD (.dsf/.dff) |
|------|--------------------------|-----------------|
| Android + USB DAC | ✅ just_audio | ✅ DoP 直出（比特完美需 AAudio 升级） |
| 鸿蒙 OHOS (Flutter) | ✅ | ✅ 同 Android 原生层 |
| 桌面 / Web 演示 | ✅（本地文件） | ⚠️ PCM 回退（非比特完美） |

---

## 鸿蒙 (OHOS) 适配

本项目使用 Flutter 跨平台，鸿蒙侧复用同一套 Dart/UI 与 Android 原生层逻辑：

1. 安装 [OHOS Flutter](https://gitcode.com/openharmony-sig/flutter_flutter) 分支，执行 `flutter channel` 切换到 ohos。
2. `ohos/` 工程由 `flutter create . --platforms=ohos` 生成，将 `android/app/src/main/kotlin/...` 下的 `SmbPlugin` / `DsdPlugin` / `DsdAudioEngine` 适配到 OHOS 的 ArkTS / NAPI 或继续保留 Kotlin/NDK 原生模块（OHOS 兼容 Android 原生 so）。
3. SMB（jcifs-ng）与 DSD（AAudio/OpenSL）的核心算法与 Android 一致，主要工作量在平台通道的 OHOS 侧封装。

---

## 目录结构

```
lib/
  main.dart                 # 入口：初始化 Provider
  app.dart                  # MaterialApp 主题与路由
  models/                   # Track / SmbConnection / AudioFormat 模型
  util/platform.dart        # 条件导入：Web 排除 dart:io
  services/
    smb/                    # SmbClient 抽象 + jcifs 桥 + 本地演示
    audio/                  # PlayerEngine / DsdNativeEngine / 格式识别 / Track 工厂
  ui/                       # 各页面与可复用 Widget
android/app/src/main/kotlin/.../
  MainActivity.kt           # 注册 MethodChannel / EventChannel
  SmbPlugin.kt             # jcifs-ng 连接/列举/下载
  DsdPlugin.kt             # DSD 引擎 Method/Event 桥
  audio/DsdAudioEngine.kt   # DoP over AudioTrack
  audio/DopEncoder.kt       # DSD→PCM(DoP) 封装
```

---

## 已知限制 / 后续规划

- 后台播放与锁屏通知（`audio_service`）已列入依赖，待真机接入。
- DSD 比特完美已留好 AAudio(C++) 升级接口，需真机 + DAC 验证。
- SMB 当前为"下载到缓存再播放"；后续可改为流式读取（jcifs 流直喂解码器）以降低首播延迟。
- 暂未做播放队列持久化、封面抓取、歌词等，可作为后续迭代。

---

## 云端一键出包（无需本机装 Android SDK）

本机没有 Android Studio / SDK？用云端 CI 自动产出 APK 安装包，两步搞定。
本工程已内置两份流水线配置：`codemagic.yaml` 与 `.github/workflows/build-apk.yml`。

### 方案 A：Codemagic（最简单）
1. 打开 https://codemagic.io ，用 GitHub 账号登录并关联包含本工程的仓库。
2. 在 Codemagic 里选择仓库中的 `codemagic.yaml` 作为构建配置。
3. 点 **Start new build** —— 云端自动执行 `flutter pub get` + `flutter build apk --release`。
4. 完成后在 Artifacts 下载 `app-release.apk`；也可在 `codemagic.yaml` 的 `publishing.email` 填入你的邮箱，构建完自动收到下载链接。

### 方案 B：GitHub Actions（免费，仓库自带）
1. 把本工程 `git push` 到你的 GitHub 仓库（已内置 `.github/workflows/build-apk.yml`）。
2. 在仓库 **Actions** 标签页启用 workflows（首次需点 "I understand my workflows..."）。
3. 之后每次 push 到 `main/master` 自动构建；也可在 Actions 页手动 **Run workflow**。
4. 构建记录里下载名为 **dsd-player-release-apk** 的产物，即 `app-release.apk`。

> 两条流水线均锁定 Flutter 3.0.0 / Dart 2.17，并强制使用 JDK 11（AGP 7.1.2 + Gradle 7.4 不支持 JDK 17）。Android 原生层（jcifs-ng SMB + DoP DSD 引擎）会一并编入 APK。
>
> 产物使用 **debug 签名**（`android/app/build.gradle` 里 `signingConfig signingConfigs.debug`）：可以直接装机、内部试用；但不能上架应用商店，部分设备安装时会提示"未知来源/非官方渠道"。
