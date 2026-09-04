# iOS Lyric Plugin

iOS 16+ 越狱歌词 HUD 插件（支持 rootless 与 roothide 打包方案），实现：

- 根据当前播放歌曲自动获取歌词（默认 Netease）
- SpringBoard 顶层 HUD 浮窗显示当前行与下一行歌词
- 卡拉 OK 式进度填充效果
- 可拖动、可锁定位置、可触摸穿透、无歌词自动隐藏
- PreferenceLoader 设置页，实时 Darwin 通知刷新

## 结构

- `Tweak.xm`: 主逻辑（播放信息监听、歌词请求、HUD 刷新、偏好设置重载）
- `LPLyricModels.*`: LRC 解析与时间同步
- `LPLyricFetcher.*`: 歌词搜索/拉取
- `LPLyricHUDView.*`: HUD 渲染和交互
- `ioslyricprefs/`: 设置页 Bundle

## 编译

使用 Theos：

```bash
make package THEOS=/path/to/theos THEOS_PACKAGE_SCHEME=rootless
make package THEOS=/path/to/theos THEOS_PACKAGE_SCHEME=roothide
```

或直接构建两种包：

```bash
make package-both THEOS=/path/to/theos
```

安装后不会自动重启用户空间或 Respring，请在你确认环境安全后再手动执行。
