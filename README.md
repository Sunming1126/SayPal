# SayPal

SayPal 是一个 Flutter iOS 英语口语练习 App。当前工程的前端从 iPhone 17 模拟器里保留的 `0.1.0 (3)` 调试包恢复，首页为 Alex 老师，主导航为「聊一聊／情景扮演／复习／我的」。

## 当前本机直接构建

本机 iOS Debug 构建已自动配置线上语音地址与测试访问凭证。你自行在 Flutter 或 Xcode 中选择设备并构建运行即可，无需每次传入 `--dart-define`。本次没有启动模拟器或 App。

凭证保存在被忽略、权限为 `600` 的 `ios/Flutter/SayPal.local.xcconfig`，仅由 Debug 配置引用；Release 和 Profile 不包含它。它是测试用客户端访问凭证，火山云端密钥仍只留在服务器。Debug 专用文件设置了完整的 `DART_DEFINES`；如要切换其他配置，先临时移走该文件，再自行传入构建参数。

iOS 和 Android 的线上语音默认走火山 RTC，使用豆包语音合成 2.0 的 Vivi 音色。麦克风音频和字幕在 RTC 房间实时传输，松手后才提交本轮，AI 音频由房间直接播放。请看 [线上检查记录](docs/ONLINE_CHECK.md)。登录按要求暂不处理。

进入「聊一聊」时建立连接，前台停留期间复用房间。切到其他标签或 App 进入后台时退出房间。Debug 日志中的 `SayPal RTC release`、`capture` 和 `reply` 分别记录松手到消息入列表、识别收尾、指令到字幕的耗时，只记录时长。

切到其他标签时，客户端预取一份「聊一聊」房间的短期令牌，回到页面时并行加入房间和启动 AI。`SayPal RTC startup` 日志显示各阶段达到就绪的时间。

换电脑或轮换凭证时，可在具备 `onesay-server` SSH 权限的电脑重新生成配置（不会启动 App）：

```sh
python3 tools/fetch_online_config.py
python3 tools/configure_ios_debug.py
```

Windows 使用 `.local/saypal-online.json` 作为 `--dart-define-from-file` 时，旧配置需把 `SAYPAL_CHAT_TRANSPORT` 改为 `rtc`。沿用原有的语音服务地址与客户端测试 Token，无需添加火山云端密钥。`websocket` 仍可显式指定用于兼容检查。

## 离线演示与本机后端

使用 Flutter 3.44、Dart 3.12、Xcode 和 CocoaPods。模拟器构建沿用恢复包的 Bundle ID `com.caoyuming.saypal`，最低支持 iOS 15。要使用演示模式，先临时移走 `ios/Flutter/SayPal.local.xcconfig`，再自行运行下列命令：

```sh
cd /Users/zhaoqing/myprojects/SayPal
flutter pub get
flutter devices
flutter run -d "iPhone 17" --dart-define=SAYPAL_CHAT_TRANSPORT=demo
```

已经编译的安装包位于 `build/ios/iphonesimulator/Runner.app`。如果要重新编译，可以运行 `flutter build ios --debug --simulator --no-codesign`。真机签名需在 Xcode 里选择自己的开发团队和可用的 App ID。

## 启动本机语音后端

```sh
cd /Users/zhaoqing/myprojects/SayPal/backend
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt
cp -n .env.example .env
.venv/bin/python -m uvicorn saypal.app:app --host 127.0.0.1 --port 8000
```

另开终端访问 `http://127.0.0.1:8000/health`。`status: ok` 代表服务已启动。`configured` 和 `rtcConfigured` 分别表示 WebSocket 语音和 RTC 所需的环境变量是否齐全。真实语音需要把语音服务和火山方舟的凭证填入 `backend/.env`。

本机语音后端配置好后，可以在项目根目录运行：

```sh
flutter run -d "iPhone 17" \
  --dart-define=SAYPAL_CHAT_TRANSPORT=websocket \
  --dart-define=SAYPAL_API_BASE_URL=http://127.0.0.1:8000
```

如果本机后端设置了 `SAYPAL_CHAT_TOKEN`，客户端需通过同名 Dart define 传入对应值。

## 恢复范围

- 从 Build 3 的 Dart Kernel 恢复了 102 个客户端 Dart 文件和 15 个内部包文件，并恢复了情景目录与原始插画。合入前的前端备份在 `.local/pre-build3-frontend`。
- `backend/` 包含语音服务和 RTC 网关。默认使用 Build 3 恢复的 RTC 链路，并适配两端共享的按住说话与字幕交互。
- 找回了登录和会员客户端代码。独立的账号与会员服务、原 Git 历史和线上服务密钥未随安装包或语音发布目录恢复。默认使用演示登录和会员服务。
