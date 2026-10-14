# Windows runner for ftl-dev.vim tests (requires vim, git; nvim for lua tests).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Test = Join-Path $Root "test"
$Vendor = Join-Path $Test "vendor\vader.vim"
$Inv = Join-Path $Test "coverage_inventory.json"

function Resolve-Exe([string[]]$Names) {
  foreach ($n in $Names) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  return $null
}

# Refresh PATH from Machine + User (winget installs often need a new shell)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
  [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Test-Path (Join-Path $Vendor "plugin\vader.vim"))) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Test "vendor") | Out-Null
  git clone --depth 1 https://github.com/junegunn/vader.vim.git $Vendor
}

$ids = (Get-Content $Inv -Raw | ConvertFrom-Json).units | ForEach-Object { $_.id }
$missing = @()
foreach ($id in $ids) {
  $hitVader = Select-String -Path (Join-Path $Test "vader\*.vader") -Pattern "coverage: $id" -SimpleMatch -Quiet
  $hitLua = $false
  $luaDir = Join-Path $Test "lua"
  if (Test-Path $luaDir) {
    $hitLua = Select-String -Path (Join-Path $luaDir "*") -Pattern "coverage: $id" -SimpleMatch -Quiet
  }
  if (-not $hitVader -and -not $hitLua) { $missing += $id }
}
if ($missing.Count -gt 0) {
  Write-Host "MISSING coverage tags:"
  $missing | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host "Coverage inventory: 100% of units tagged in vader/lua cases."

$vim = Resolve-Exe @("vim", "vim.exe")
if (-not $vim) { throw "vim not found on PATH - install with: winget install -e --id vim.vim" }

$vimrc = (Join-Path $Test "vimrc") -replace '\\', '/'
$smoke = (Join-Path $Test "syntax_smoke.vim") -replace '\\', '/'
$vaderGlob = (Join-Path $Test "vader\*.vader") -replace '\\', '/'

Write-Host "Running syntax smoke..."
& $vim -Nu $vimrc -S $smoke
if ($LASTEXITCODE -ne 0) { throw "syntax_smoke failed (exit $LASTEXITCODE)" }
Write-Host "Syntax smoke passed."

Write-Host "Running Vader suite..."
& $vim -Nu $vimrc -c "Vader! $vaderGlob" -c "qa!"
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
  throw "Vader suite failed (exit $LASTEXITCODE)"
}
Write-Host "Vader suite passed."

$nvim = Resolve-Exe @("nvim", "nvim.exe")
if ($nvim) {
  $rootFwd = $Root -replace '\\', '/'
  $luaTest = (Join-Path $Test "lua\lsp_test.lua") -replace '\\', '/'
  Write-Host "Running Neovim lua lsp tests..."
  & $nvim --headless -u NONE `
    -c "set rtp^=$rootFwd" `
    -c "luafile $luaTest" `
    -c "qa!"
  if ($LASTEXITCODE -ne 0) { throw "Neovim lua tests failed (exit $LASTEXITCODE)" }
  Write-Host "Neovim lua lsp tests passed."
} else {
  Write-Host "nvim not found - skipping lua/ftl_dev/lsp.lua tests (install: winget install -e --id Neovim.Neovim)."
  exit 1
}

Write-Host "All vim tests passed (inventory 100% + smoke + vader + lua)."
