# vendor/ — 本地构建用的第三方运行时

这个目录**不会被提交到 git**（见根目录 `.gitignore`）。

构建一键安装包前，请把 UE4SS 官方发布的 Windows zip 放在这里，命名为：

```
vendor/ue4ss_runtime.zip
```

本项目使用的是 **UE4SS v3.0.1 实验版**（UE 5.6）：

- 发布页：https://github.com/UE4SS-RE/RE-UE4SS/releases
- 版本标签：`experimental-latest`
- 文件名：`UE4SS_v3.0.1-1220-ga9ffb667.zip`

也可以用命令行参数指定别处的文件：

```bash
python tools/build_installer.py --ue4ss "D:\下载\UE4SS_xxx.zip"
```

UE4SS 采用 MIT 许可。若把它的二进制随安装包分发，请一并附上根目录的
`LICENSE-UE4SS.txt`。源文件：https://github.com/UE4SS-RE/RE-UE4SS/blob/main/LICENSE
