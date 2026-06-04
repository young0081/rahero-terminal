本地素材种子目录

用途：存放「受版权保护、可在本地 exe 内使用，但不提交进开源仓库」的素材。
典型用例：从游戏息屏动态图标视频截取的势力 LOGO 帧，作为飞讯头像等。

工作机制：
- 这些素材文件被 .gitignore 排除，不会进入开源版本库（仅此 README 入库以保证目录存在）。
- flutter build 时仍会把本目录的文件打进 app（构建读磁盘，不读 git），所以本地打出的
  exe / apk 能直接显示这些素材。
- 程序加载顺序：本地下载缓存 → 本目录种子（local_seed）→ 代码绘制占位图。
- 正式发布时，应改为把素材上传到库街区，由程序运行时按 asset_manifest.json 下载。

命名约定：文件名与 asset_manifest.json 中对应资源的 id 一致，扩展名 .png，
例如 id 为 avatar_xingju 的资源对应 avatar_xingju.png。
