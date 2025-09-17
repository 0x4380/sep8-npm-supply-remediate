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
  "@ahmedhfarag/ngx-perfect-scrollbar" = @("20.0.20")
  "@ahmedhfarag/ngx-virtual-scroller"  = @("4.0.4")
  "@art-ws/common"            = @("2.0.28")
  "@art-ws/config-eslint"     = @("2.0.4","2.0.5")
  "@art-ws/config-ts"         = @("2.0.7","2.0.8")
  "@art-ws/db-context"        = @("2.0.24")
  "@art-ws/di-node"           = @("2.0.13")
  "@art-ws/di"                = @("2.0.28","2.0.32")
  "@art-ws/eslint"            = @("1.0.5","1.0.6")
  "@art-ws/fastify-http-server" = @("2.0.24","2.0.27")
  "@art-ws/http-server"       = @("2.0.21","2.0.25")
  "@art-ws/openapi"           = @("0.1.9","0.1.12")
  "@art-ws/package-base"      = @("1.0.5","1.0.6")
  "@art-ws/prettier"          = @("1.0.5","1.0.6")
  "@art-ws/slf"               = @("2.0.15","2.0.22")
  "@art-ws/ssl-info"          = @("1.0.9","1.0.10")
  "@art-ws/web-app"           = @("1.0.3","1.0.4")
  "@crowdstrike/commitlint"        = @("8.1.1","8.1.2")
  "@crowdstrike/falcon-shoelace"   = @("0.4.1","0.4.2")
  "@crowdstrike/foundry-js"        = @("0.19.1","0.19.2")
  "@crowdstrike/glide-core"        = @("0.34.2","0.34.3")
  "@crowdstrike/logscale-dashboard"= @("1.205.1","1.205.2")
  "@crowdstrike/logscale-file-editor" = @("1.205.1","1.205.2")
  "@crowdstrike/logscale-parser-edit" = @("1.205.1","1.205.2")
  "@crowdstrike/logscale-search"   = @("1.205.1","1.205.2")
  "@crowdstrike/tailwind-toucan-base" = @("5.0.1","5.0.2")
  "@ctrl/deluge"            = @("7.2.1","7.2.2")
  "@ctrl/golang-template"   = @("1.4.2","1.4.3")
  "@ctrl/magnet-link"       = @("4.0.3","4.0.4")
  "@ctrl/ngx-codemirror"    = @("7.0.1","7.0.2")
  "@ctrl/ngx-csv"           = @("6.0.1","6.0.2")
  "@ctrl/ngx-emoji-mart"    = @("9.2.1","9.2.2")
  "@ctrl/ngx-rightclick"    = @("4.0.1","4.0.2")
  "@ctrl/qbittorrent"       = @("9.7.1","9.7.2")
  "@ctrl/react-adsense"     = @("2.0.1","2.0.2")
  "@ctrl/shared-torrent"    = @("6.3.1","6.3.2")
  "@ctrl/tinycolor"         = @("4.1.1","4.1.2")
  "@ctrl/torrent-file"      = @("4.1.1","4.1.2")
  "@ctrl/transmission"      = @("7.3.1")
  "@ctrl/ts-base32"         = @("4.0.1","4.0.2")
  "@hestjs/core"            = @("0.2.1")
  "@hestjs/cqrs"            = @("0.1.6")
  "@hestjs/demo"            = @("0.1.2")
  "@hestjs/eslint-config"   = @("0.1.2")
  "@hestjs/logger"          = @("0.1.6")
  "@hestjs/scalar"          = @("0.1.7")
  "@hestjs/validation"      = @("0.1.6")
  "@nativescript-community/arraybuffers" = @("1.1.6","1.1.7","1.1.8")
  "@nativescript-community/gesturehandler" = @("2.0.35")
  "@nativescript-community/perms" = @("3.0.5","3.0.6","3.0.7","3.0.8")
  "@nativescript-community/sentry" = @("4.6.43")
  "@nativescript-community/sqlite" = @("3.5.2","3.5.3","3.5.4","3.5.5")
  "@nativescript-community/text" = @("1.6.9","1.6.10","1.6.11","1.6.12","1.6.13")
  "@nativescript-community/typeorm" = @("0.2.30","0.2.31","0.2.32","0.2.33")
  "@nativescript-community/ui-collectionview" = @("6.0.6")
  "@nativescript-community/ui-document-picker" = @("1.1.27","1.1.28")
  "@nativescript-community/ui-drawer" = @("0.1.30")
  "@nativescript-community/ui-image" = @("4.5.6")
  "@nativescript-community/ui-label" = @("1.3.35","1.3.36","1.3.37")
  "@nativescript-community/ui-material-bottom-navigation" = @("7.2.72","7.2.73","7.2.74","7.2.75")
  "@nativescript-community/ui-material-bottomsheet" = @("7.2.72")
  "@nativescript-community/ui-material-core-tabs" = @("7.2.72","7.2.73","7.2.74","7.2.75","7.2.76")
  "@nativescript-community/ui-material-core" = @("7.2.72","7.2.73","7.2.74","7.2.75","7.2.76")
  "@nativescript-community/ui-material-ripple" = @("7.2.72","7.2.73","7.2.74","7.2.75")
  "@nativescript-community/ui-material-tabs" = @("7.2.72","7.2.73","7.2.74","7.2.75")
  "@nativescript-community/ui-pager" = @("14.1.36","14.1.37","14.1.38")
  "@nativescript-community/ui-pulltorefresh" = @("2.5.4")
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
