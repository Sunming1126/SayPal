# SayPal 线上检查

检查日期：2026-11-25。依据本轮真实 HTTP/WebSocket 请求及服务器内直接上游诊断；未启动模拟器、未安装或启动 App、未使用麦克风。登录检查已按用户要求搁置。

## 语音合成修复

线上 SayPal 已切换至 `/opt/saypal/voice/releases/20261125-tts-v3`。后端使用原有的 `RTC_TTS_APP_ID` 和 `RTC_TTS_ACCESS_TOKEN` 调用豆包语音 V3，资源为 `seed-tts-2.0`，音色为 Vivi 2.0。公网 WebSocket 文字回合收到 3 段对应的 MP3，共 48,135 字节，全部完成。部署前后 LifePages、Nginx 和其他运行中的容器状态一致。回滚镜像为 `saypal-voice:rollback-before-tts-v3`，原发布目录为 `/opt/saypal/voice/releases/20260910T054713Z`。

切换后，从本机通过公网 WebSocket 发送一段合成英语 PCM，服务识别为 `Hello. I like apples.`，返回 4 段与文字逐一对应的 MP3。所有片段均通过 FFmpeg 解码，共 6.34 秒。此检查覆盖服务端语音往返，设备上的录音和播放仍待验收。

以下保留切换前的检查记录。

## 默认构建配置

- iOS Debug 自动注入 `SAYPAL_API_BASE_URL`、`SAYPAL_CHAT_TRANSPORT`、`SAYPAL_CHAT_TOKEN`。Xcode 实际构建设置读取成功，三个键均存在，未输出值。
- Release/Profile 实际构建设置不包含上述凭证。
- 线上地址：`https://onesay.top/saypal/voice`。客户端使用 WebSocket，不设置旧版 RTC HTTP 实现的启动参数。
- `.local/saypal-online.json` 与 `ios/Flutter/SayPal.local.xcconfig` 均为本机私有配置、权限 `600`、已加入忽略规则。后者仅在 Debug 中引用。
- 本轮验证了 Xcode 配置解析，尚未重新编译或进行设备验收。

## 基础功能

| 项目 | 实际结果 |
| --- | --- |
| 公网健康与客户端鉴权 | 健康检查 200；缺少或错误凭证的 HTTP/WebSocket 请求均被 403 拒绝；有效凭证可建立 WebSocket |
| AI 文字对话 | 自由对话、内置角色扮演、自定义角色扮演、中译英、英文问答均收到文字回复及结束事件 |
| 练习进度 | 角色扮演返回 `practice_progress`，两类主题练习返回 `tutor_progress` |
| AI 自定义情景 | 真实生成请求 200，返回三个目标 |
| 翻译 | 首轮出现一次 502；容器内复测成功，随后公网连续三次 200 且译文非空；不能据此声称长期稳定 |
| 语音合成 | **失败**。各模式均无音频；直接上游请求返回 HTTP 403 / code 3001：`[resource_id=volc.tts.default] requested resource not granted` |
| 语音识别 | **通过合成输入测试**。使用已验证非空且有信号的 55,252 字节 PCM，收到 4 个 partial 事件及正确最终文本 `Hello. I like apples.`，随后收到 AI 文字回复。首轮空输入造成的 `45000002` 结论已撤回；尚未进行设备麦克风验收 |
| RTC 生命周期 | bootstrap/start/stop 均 200，测试任务已停止；没有加入 RTC 房间接收音频，不能视为音频链路验收通过 |
| 课程视频 | 三个主题课程的 `videoUrl`、`vttUrl` 均为空，当前为“视频准备中”占位 |

页面、档案、生词本、学习记录的原恢复检查记录存在于前序任务。本轮未启动 App 重做这些界面或持久化验收。

## 机器检查

- Dart 分析：无 error/warning，16 条既有风格 info；由于默认分析器将 info 计入退出条件，命令退出码为 1。
- 本轮重新运行了原任务的后端隔离测试：未配置状态、鉴权、翻译、情景生成、自由文字/PCM 输入及全部练习模式通过。使用的是替身上游，不能替代真实 ASR/TTS 验收。
- 新增 Python 工具语法检查通过。
- 真实请求脱敏结果位于 `.local/online-check.json`、`.local/asr-check.json`、`.local/translation-check.json`、`.local/build-settings-check.json`。这些文件均未包含凭证值。

## 服务器边界

本轮未修改线上文件、未部署、未重启容器或其他服务。只访问现有 SayPal 接口及在容器内进行小量合成数据探测；RTC 测试任务已调用 stop。语音合成的资源授权问题仍待修复，不能将当前基础功能整体标记为正常。
