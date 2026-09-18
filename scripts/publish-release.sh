#!/usr/bin/env bash
# Called only after the complete build workflow succeeds.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
inputs=${1:?artifact directory required}
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
python3 scripts/release-assets.py prepare "$inputs" "$output"
version=$(sed -n 's/^PKG_VERSION:=//p' frp/Makefile)
revision=$(sed -n 's/^PKG_RELEASE:=//p' frp/Makefile)
tag="v${version}-${revision}"
commit=$(git rev-parse HEAD)
notes=$(mktemp)
trap 'rm -rf "$output"; rm -f "$notes"' EXIT
cat > "$notes" <<EOF
FRP **${version}**，软件包修订 **${revision}**。

提供四类架构的 frpc / frps 安装包，均由 **ImmortalWrt 25.12.2 官方 SDK** 构建：

| 架构名称 | 构建目标 |
| --- | --- |
| x86_64 | x86/64 |
| aarch64_cortex-a53 | mediatek/filogic |
| arm_cortex-a7_neon-vfpv4 | ipq40xx/generic |
| mipsel_24kc | ramips/mt7621 |

请按设备的软件包架构和固件系列选择，不能仅凭 ARM/MIPS 名称通用安装。APK 不能用于 opkg/IPK 系统，也不是刷机固件。其他固件建议继续使用 feed 编译。

升级前备份配置；旧版 LuCI 的 INI 专用配置需按说明选择兼容模式。软件包构建测试不等于所有目标设备都已实测。

SHA256SUMS 提供文件校验值，build-provenance.zip 保存 SDK 和 feed 来源。下方 Source code 为源码归档。

每种架构附有 frp_架构.pem 公钥。确认信任本项目并核对校验值后，将对应公钥放入 /etc/apk/keys/，再安装 APK；不需要关闭签名验证。私钥不发布。

[使用与安装说明](https://github.com/$GH_REPO/blob/$tag/README.md) · [配置说明](https://github.com/$GH_REPO/blob/$tag/docs/CONFIGURATION.md) · [本次构建](https://github.com/$GH_REPO/actions/runs/$GITHUB_RUN_ID)
EOF
if gh release view "$tag" >/dev/null 2>&1; then
    published=$(gh release view "$tag" --json targetCommitish --jq '.targetCommitish')
    test "$published" = "$commit" || { echo 'Release tag points to another commit.'; exit 1; }
    draft=$(gh release view "$tag" --json isDraft --jq '.isDraft')
    if [[ "$draft" == false ]]; then
        echo "Release $tag is already published."
        exit 0
    fi
else
    gh release create "$tag" --target "$commit" --title "$tag" --notes-file "$notes" --draft
fi
# Keep incomplete uploads in a draft. A failed job can safely be rerun.
gh release upload "$tag" "$output"/* --clobber
gh release edit "$tag" --notes-file "$notes" --draft=false --latest
