# 仓库发布与初始化

本文面向项目维护者，说明源码仓库的初始化与发布方式。固件集成和服务配置见 [README](../README.md)。

项目仓库：[itwxf0818/openwrt-frp](https://github.com/itwxf0818/openwrt-frp)。

## Git 提交

已有仓库使用常规 Git 流程提交变更：

```sh
git pull --ff-only origin main
git add <files>
git commit -m "docs: update project documentation"
git push origin main
```

提交前确认文件范围，避免包含构建缓存、部署配置或认证信息。`work/` 与 `dist/` 已列入忽略规则。

## Windows 初始化脚本

`START-UPLOAD.cmd` 用于将完整源码目录初始化并推送至 `itwxf0818/openwrt-frp`：

1. 解压源码归档，进入项目根目录。
2. 运行 `START-UPLOAD.cmd`。
3. 如需认证，在 Git 打开的浏览器页面完成 GitHub 登录。
4. 推送成功后，在 [Actions](https://github.com/itwxf0818/openwrt-frp/actions) 查看构建任务。

脚本依赖 Git for Windows，使用 main 分支，仅设置当前仓库的提交身份与远端地址。提交邮箱采用 `itwxf0818@users.noreply.github.com` 格式，认证由 Git Credential Manager 管理。

此脚本针对上述仓库配置，Fork 或迁移仓库时需调整远端地址与提交身份。远端历史冲突或权限校验失败时，脚本会终止推送；应先核实原因并同步变更，再重新执行。

## 网页初始化

GitHub 网页支持通过 **Add file → Upload files** 上传源码。空仓库可使用 **uploading an existing file** 入口。

上传内容应位于仓库根目录，并完整保留以下结构：

```text
Makefile
README.md
files/
scripts/
tests/
docs/
.github/
.gitattributes
.gitignore
```

上传解压后的源码文件，不额外嵌套项目目录。文件选择器隐藏点文件时，需确认 `.github` 等目录已包含在提交中。

## 工作流检查

- **Build and validate**：main 分支提交、Pull Request 或手动触发时执行验证和 SDK 构建。
- **Update FRP**：定时或手动检查上游稳定版；发现新版本后执行完整验证，通过后提交更新。
- **Artifacts**：构建成功后提供软件包及 SDK/feed 来源记录。

维护者需确认仓库已启用 Actions，并允许更新工作流的提交任务使用 `contents: write`。分支保护与组织策略的处理方式见 [维护说明](../README.md#维护说明)。
