# Launch Vim/Neovim with this repo's vim/ on runtimepath (no plugin manager).
# Usage (from anywhere):
#   powershell -File vim/test/dev.ps1
#   powershell -File vim/test/dev.ps1 path\to\file.ftl
#   powershell -File vim/test/dev.ps1 -Nvim
param(
  [switch]$Nvim,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Files
)
$ErrorActionPreference = "Stop"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
  [System.Environment]::GetEnvironmentVariable("Path", "User")

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$vimrc = Join-Path $Root "test\vimrc"
$rootFwd = $Root -replace '\\', '/'

if (-not $Files -or $Files.Count -eq 0) {
  $sample = Join-Path $env:TEMP "ftl-dev-sample.ftl"
  @"
<#-- ftl-dev local smoke -->
<#assign name = "world">
Hello `${"$"}{name}`!
<#if true>
  nested
</#if>
"@ | Set-Content -Encoding utf8 $sample
  $Files = @($sample)
}

if ($Nvim) {
  $nvim = (Get-Command nvim -ErrorAction SilentlyContinue).Source
  if (-not $nvim) { throw "nvim not found - winget install -e --id Neovim.Neovim" }
  & $nvim -u NONE `
    -c "set rtp^=$rootFwd" `
    -c "filetype plugin indent on" `
    -c "syntax enable" `
    @Files
} else {
  $vim = (Get-Command vim -ErrorAction SilentlyContinue).Source
  if (-not $vim) { $vim = (Get-Command vim.exe -ErrorAction SilentlyContinue).Source }
  if (-not $vim) { throw "vim not found - winget install -e --id vim.vim (then add Local\Programs\Vim to PATH)" }
  & $vim -Nu $vimrc @Files
}
