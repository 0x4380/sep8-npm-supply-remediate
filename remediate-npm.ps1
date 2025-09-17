#Requires -Version 5
param(
  [ValidateSet("--detect","--fix")]
  [string]$Mode="--detect",
  [switch]$Yes,
  [switch]$ReinstallGlobal,
  [switch]$AllowNoLock
)

$ErrorActionPreference = "Stop"

# --- Предохранители: только локальные машины
if ($env:CI -eq "true" -or $env:CI -eq "1") {
  Write-Host "[!] CI среда обнаружена. Скрипт только для локальных рабочих машин."; exit 2
}

$log = Join-Path (Get-Location) "remediate-npm.ps1.log"
Start-Transcript -Path $log -Append | Out-Null

function Ensure-Cmd($name) { if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { Write-Host "[!] Требуется $name"; Stop-Transcript | Out-Null; exit 2 } }
Ensure-Cmd node
Ensure-Cmd npm

# --- Чёрный список (точные версии)
$Affected = @{
  "ansi-styles"         = @("6.2.2")
  "debug"               = @("4.4.2")
  "chalk"               = @("5.6.1")
  "supports-color"      = @("10.2.1")
  "strip-ansi"          = @("7.1.1")
  "ansi-regex"          = @("6.2.1")
  "wrap-ansi"           = @("9.0.1")
  "color-convert"       = @("3.1.1")
  "color-name"          = @("2.0.1")
  "is-arrayish"         = @("0.3.3")
  "slice-ansi"          = @("7.1.1")
  "color"               = @("5.0.1")
  "color-string"        = @("2.1.1")
  "simple-swizzle"      = @("0.2.3")
  "supports-hyperlinks" = @("4.1.1")
  "has-ansi"            = @("6.0.1")
  "chalk-template"      = @("1.1.1")
  "backslash"           = @("0.2.1")
  "@crowdstrike/commitlint"        = @("8.1.1","8.1.2")
  "@crowdstrike/falcon-shoelace"   = @("0.4.1","0.4.2")
  "@crowdstrike/foundry-js"        = @("0.19.1","0.19.2")
  "@crowdstrike/glide-core"        = @("0.34.2","0.34.3")
  "@crowdstrike/logscale-dashboard"= @("1.205.1","1.205.2")
  "@crowdstrike/logscale-file-editor" = @("1.205.1","1.205.2")
  "@crowdstrike/logscale-parser-edit" = @("1.205.1","1.205.2")
  "@crowdstrike/logscale-search"   = @("1.205.1","1.205.2")
  "@crowdstrike/tailwind-toucan-base" = @("5.0.1","5.0.2")
}

# --- Контекст проекта / lock
$InProject = Test-Path -Path "package.json"
$LockKind  = "none"
if ($InProject) {
  if (Test-Path "pnpm-lock.yaml") { $LockKind = "pnpm-lock" }
  elseif (Test-Path "yarn.lock")  { $LockKind = "yarn-lock" }
  elseif (Test-Path "npm-shrinkwrap.json") { $LockKind = "npm-shrinkwrap" }
  elseif (Test-Path "package-lock.json")   { $LockKind = "npm-lock" }
  else {
    $LockKind = "no-lock"
    Write-Host "[!] Lock-файл не найден. Возможен дрейф зависимостей."
    if (-not $AllowNoLock) { Write-Host "    Добавьте --AllowNoLock для обновления без lock."; }
  }
} else {
  Write-Host "[i] package.json не найден. Локальная ремедиация будет пропущена."
}

# --- Сканирование
Write-Host "[-] Сканирую локальные и глобальные зависимости…"

function NpmLsJson([string[]]$Args) {
  try { return (npm @Args --all --json | Out-String | ConvertFrom-Json) } catch { return $null }
}
function Walk($node, [System.Collections.ArrayList]$acc) {
  if ($null -eq $node) { return $acc }
  if ($node.name -and $node.version) { [void]$acc.Add([pscustomobject]@{name=$node.name;version=$node.version}) }
  if ($node.dependencies) { foreach ($k in $node.dependencies.Keys) { Walk $node.dependencies[$k] $acc | Out-Null } }
  return $acc
}
function Find-Hits($list) {
  $hits = @()
  foreach ($p in ($list | Where-Object { $_ })) {
    if ($Affected.ContainsKey($p.name) -and $Affected[$p.name] -contains $p.version) { $hits += $p }
  }
  return $hits
}

$localTree  = NpmLsJson @("ls")
$globalTree = NpmLsJson @("ls","-g")

$localHits  = if ($localTree)  { Find-Hits (Walk $localTree  ([System.Collections.ArrayList]@())) } else { @() }
$globalHits = if ($globalTree) { Find-Hits (Walk $globalTree ([System.Collections.ArrayList]@())) } else { @() }

if (-not $localHits.Count -and -not $globalHits.Count) {
  Write-Host "[+] Скомпрометированных версий не найдено. ✅"
} else {
  Write-Host "[!] Обнаружены совпадения:"
  if ($localHits.Count)  { Write-Host "  LOCAL:";  $localHits  | ForEach-Object { Write-Host "   - $($_.name)@$($_.version)" } }
  if ($globalHits.Count) { Write-Host "  GLOBAL:"; $globalHits | ForEach-Object { Write-Host "   - $($_.name)@$($_.version)" } }
}

if ($Mode -eq "--detect") {
  if ($localHits.Count -or $globalHits.Count) { Stop-Transcript | Out-Null; exit 1 } else { Stop-Transcript | Out-Null; exit 0 }
}
if ($Mode -ne "--fix") { Write-Host "[!] Используйте --detect или --fix"; Stop-Transcript | Out-Null; exit 2 }

Write-Host "`n[*] Режим фикса. Lock-файлы не трогаем."

function Confirm-Ask($Prompt){
  if ($Yes) { return $true }
  $ans = Read-Host "$Prompt [y/N]"
  return @("y","yes") -contains ($ans.ToLower())
}

# --- Списки пакетов
$LocalNames  = $localHits  | Select-Object -ExpandProperty name -Unique
$GlobalNames = $globalHits | Select-Object -ExpandProperty name -Unique

# --- Глобальные
$npmPrefix = (& npm config get prefix) 2>$null
$allowGlobal = $false
if ($npmPrefix) {
  $up = ($env:USERPROFILE -replace '\\','\').ToLower()
  $pf = ($npmPrefix -replace '\\','\').ToLower()
  if ($pf.StartsWith($up)) { $allowGlobal = $true }
}

if ($allowGlobal -and $GlobalNames.Count) {
  Write-Host "[*] План глобальной очистки: $($GlobalNames -join ', ')"
  if (Confirm-Ask "→ Удалить глобальные пакеты?") {
    npm uninstall -g @GlobalNames 2>$null | Out-Null
    if ($ReinstallGlobal) {
      $pkgs = $GlobalNames | ForEach-Object { "$_@latest" }
      npm i -g @pkgs 2>$null | Out-Null
    }
  }
}

# --- Локальные
if ($InProject -and ($LockKind -ne "no-lock" -or $AllowNoLock) -and $LocalNames.Count) {
  Write-Host "[*] План локального обновления: $($LocalNames -join ', ')"
  if (Confirm-Ask "→ Обновить локальные зависимости?") {
    switch ($LockKind) {
      "npm-lock" { npm prune 2>$null | Out-Null; npm dedupe 2>$null | Out-Null; npm update @LocalNames 2>$null | Out-Null }
      "npm-shrinkwrap" { npm prune 2>$null | Out-Null; npm dedupe 2>$null | Out-Null; npm update @LocalNames 2>$null | Out-Null }
      "yarn-lock" {
        if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) { Write-Host "[!] Yarn не найден."; }
        else {
          $args = $LocalNames | ForEach-Object { "$_@latest" }
          yarn up @args | Out-Null
        }
      }
      "pnpm-lock" {
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) { Write-Host "[!] pnpm не найден."; }
        else { pnpm update @LocalNames --latest | Out-Null }
      }
      "no-lock" { npm update @LocalNames 2>$null | Out-Null }
    }
    Write-Host "[+] Локальные зависимости обновлены."
  }
}

Write-Host "`n[*] Рекомендуется пересоздать npm-токены и проверить SSH-ключи."
Write-Host "[+] Готово."
Stop-Transcript | Out-Null
