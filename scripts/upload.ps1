# First upload helper. Never force-pushes and never changes global Git settings.
$ErrorActionPreference = 'Stop'
try {
    $repo = Split-Path -Parent $PSScriptRoot
    Set-Location -LiteralPath $repo
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitPath = Join-Path $env:ProgramFiles 'Git\cmd'
        if (Test-Path -LiteralPath (Join-Path $gitPath 'git.exe')) {
            $env:PATH = "$gitPath;$env:PATH"
        } else { throw 'Git is not installed. Use the web upload instructions in docs/UPLOAD.md.' }
    }
    function Invoke-Git {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "Git failed: $($args[0]). See the message above." }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
        Invoke-Git init -b main
    }
    $actualRoot = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or (Resolve-Path -LiteralPath $actualRoot).Path -ne (Resolve-Path -LiteralPath $repo).Path) {
        throw 'Unexpected Git repository root.'
    }
    $branch = (& git symbolic-ref --short HEAD).Trim()
    if ($branch -ne 'main') { throw 'This first-upload helper expects the main branch.' }
    Invoke-Git config --local core.autocrlf false
    # Repository-local privacy identity, not your real email address.
    Invoke-Git config --local user.name itwxf0818
    Invoke-Git config --local user.email itwxf0818@users.noreply.github.com
    $expectedRemote = 'https://github.com/itwxf0818/openwrt-frp.git'
    $remotes = & git remote
    if ($remotes -contains 'origin') {
        $actualRemote = (& git remote get-url origin).Trim()
        if ($actualRemote -ne $expectedRemote) { throw 'origin points to another repository; stopping.' }
    } else {
        Invoke-Git remote add origin $expectedRemote
    }
    Invoke-Git add -- Makefile README.md LICENSE .gitattributes .gitignore START-UPLOAD.cmd .github files scripts tests docs
    # The index records POSIX executable bits even when uploaded from Windows.
    Invoke-Git update-index --chmod=+x files/frpc.init files/frps.init scripts/build-sdk.sh tests/test_init.sh
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        Invoke-Git commit -m 'Add maintained FRP packages and validated update workflow'
    } elseif ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged changes.' }
    Write-Host 'Uploading to itwxf0818/openwrt-frp. Sign in through the browser if Git asks.'
    Invoke-Git push -u origin main
    Write-Host 'SUCCESS. Open https://github.com/itwxf0818/openwrt-frp/actions to see the build.'
} catch {
    Write-Host "UPLOAD STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'No force push was used. Keep this window and share the error message for help.'
    exit 1
}
