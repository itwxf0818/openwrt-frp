#!/usr/bin/env bash
# Run only after publishing; VERSION describes the latest published release.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
version=$(sed -n 's/^PKG_VERSION:=//p' frp/Makefile)
revision=$(sed -n 's/^PKG_RELEASE:=//p' frp/Makefile)
tag="v${version}-${revision}"
latest=$(gh release view --json tagName,isDraft,isPrerelease --jq 'select(.isDraft == false and .isPrerelease == false) | .tagName')
[[ "$latest" = "$tag" ]] || { echo 'Latest published release differs; VERSION unchanged.'; exit 1; }
branch=$(gh api "repos/$GH_REPO" --jq '.default_branch')
current=$(gh api "repos/$GH_REPO/contents/VERSION" -f "ref=$branch" --method GET)
content=$(printf '%s' "$current" | jq -r '.content' | base64 --decode)
if [[ "$content" = "$tag" ]]; then
    echo "VERSION already records $tag."
    exit 0
fi
sha=$(printf '%s' "$current" | jq -r '.sha')
encoded=$(printf '%s\n' "$tag" | base64 -w0)
gh api "repos/$GH_REPO/contents/VERSION" --method PUT \
    -f "branch=$branch" -f "sha=$sha" -f "content=$encoded" \
    -f "message=chore: release FRP $tag [skip ci]" --silent
echo "VERSION updated to $tag after successful publication."
