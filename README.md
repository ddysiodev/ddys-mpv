# ddys-mpv

`ddys-mpv` 是低端影视 API 的 mpv Lua 播放器脚本。安装后可以在 mpv 里直接浏览 DDYS 分类、搜索影片、查看资源线路并播放 m3u8/mp4/mpd 等链接。

## 功能

- 首页菜单：最新更新、热门内容、电影、剧集、动漫、综艺、纪录片
- 搜索：通过 mpv console 输入关键词
- 详情页：拉取 DDYS 资源线路并按偏好排序
- 播放：`loadfile` 直接播放 URL
- 线路：自动优先直链和高质量关键词
- 外部资源：可显示网盘、磁力、页面资源
- 收藏/稍后看：本地 JSON 文件
- 播放历史：本地 JSON 文件
- 导出播放列表：M3U、PLS
- 配置：API Base、API Key、分页、菜单行数、快捷键、直链策略
- 安装脚本：Windows、macOS、Linux

## 安装

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install\install.ps1
```

macOS/Linux：

```bash
sh install/install.sh
```

安装后文件位置：

```text
scripts/ddys-mpv.lua
script-opts/ddys-mpv.conf
```

## 使用

启动 mpv 后按：

```text
Ctrl+d  打开 DDYS 菜单
Ctrl+s  搜索
Ctrl+l  最新更新
Ctrl+h  播放历史
Ctrl+f  收藏/稍后看
```

菜单打开后：

```text
↑/↓       选择
Enter    打开/播放
Backspace 返回首页
Esc      关闭菜单
```

搜索会打开 mpv console，输入关键词后回车即可。也可以手动执行：

```text
script-message ddys-mpv-search 关键词
```

## 配置

编辑 `script-opts/ddys-mpv.conf`：

```text
api_base=https://ddys.io/api/v1
site_base=https://ddys.io
api_key=
http_command=curl
page_size=24
home_limit=24
prefer_keywords=1080,2160,4k,蓝光,高清,m3u8,mp4
include_external=yes
direct_only=no
auto_play_best=no
```

如果你部署了自己的 DDYS API 代理，把 `api_base` 改成代理地址即可。

## 数据文件

默认写入 mpv 配置目录：

```text
ddys-mpv-history.json
ddys-mpv-favorites.json
<slug>.m3u
<slug>.pls
```

也可以用 `data_dir` 指定目录。指定目录需要提前存在。

## 依赖

脚本通过 `curl` 请求 DDYS API。Windows 10/11、macOS 和多数 Linux 发行版通常已内置 curl；如果没有，请安装 curl 或把 `http_command` 改成可兼容 curl 参数的命令。

## 卸载

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install\uninstall.ps1
```

macOS/Linux：

```bash
sh install/uninstall.sh
```

## License

MIT
