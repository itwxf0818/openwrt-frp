# 第一次上传：不需要写代码

目标仓库：[itwxf0818/openwrt-frp](https://github.com/itwxf0818/openwrt-frp)。交付时没有调用 GitHub connector，因此**文件尚未上传**。

## 最简单：Windows 上传助手

1. 把交付的 ZIP **完整解压**，进入 `openwrt-frp` 文件夹。
2. 双击 **START-UPLOAD.cmd**。不要直接在压缩包里双击。
3. 如果 Git 打开浏览器要求登录，使用你拥有 `itwxf0818/openwrt-frp` 的 GitHub 账号登录授权。
4. 出现 **SUCCESS** 后，打开[仓库 Actions](https://github.com/itwxf0818/openwrt-frp/actions)，查看 **Build and validate**。

助手会创建本地 Git 仓库、提交项目文件并推送到目标仓库的 main 分支；只设置当前仓库的 Git 身份，使用 `itwxf0818@users.noreply.github.com` 隐私邮箱格式，不改电脑全局设置。它不会上传 `work` 构建缓存，不会强制覆盖远端提交，也不会向你索要或保存 token。

如 Git 提示没有权限、远端已有其他提交，或组织要求额外授权，脚本会停在错误处。把窗口里的错误文字发回来即可，不要自行使用 force push。脚本已做语法检查，但交付阶段未执行真实推送。

## 不运行助手：浏览器上传

1. 打开目标仓库；空仓库点击 **uploading an existing file**，非空仓库使用 **Add file → Upload files**。
2. 在已解压的 `openwrt-frp` 文件夹中选择**里面的全部文件和文件夹**，拖到上传区。不要把外层 `openwrt-frp` 文件夹整体作为子目录上传，也不要上传 ZIP 本身。
3. 确认上传列表含 `.github/workflows/build.yml`、`.github/workflows/update-frp.yml`，以及根目录的 `Makefile` 和 `README.md`。
4. 填写提交说明，例如 `Initial FRP package feed`，点击 **Commit changes**，默认分支使用 main。
5. 打开 Actions 查看首次构建。GitHub 若提示启用工作流，选择允许。

如果文件选择器隐藏以点开头的文件，使用 Windows 资源管理器显示隐藏项目，确认 `.github`、`.gitattributes`、`.gitignore` 都上传了。漏掉 `.github` 就不会自动更新。

## 上传后应看到什么

- 根目录有 Makefile、README.md、files、scripts、tests、docs、.github。
- Actions 出现 Build and validate，先完成源码验证，再构建三组 SDK 软件包。
- 全部绿色后，运行页面底部 Artifacts 提供软件包和构建来源记录。
- Update FRP 可以手动 Run workflow；已经是最新版本时只显示“没有更新”，不会重复提交。

完整使用方法见 [README](../README.md)。这一步完成的是源码项目上线；把它接进你的固件编译流程之后，才会生成适合你具体设备的软件包。
