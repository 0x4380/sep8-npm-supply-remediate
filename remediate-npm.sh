#!/usr/bin/env bash
set -euo pipefail

# --- Предохранители: только интерактивные рабочие станции
if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
  echo "[!] CI среда обнаружена. Скрипт только для локальных рабочих машин."; exit 2
fi
if [[ ! -t 1 || ! -t 0 ]]; then
  echo "[!] Нет интерактивного TTY. Скрипт рассчитан на ручной запуск."; exit 2
fi

LOGFILE="./remediate-npm.log"
exec > >(tee -a "$LOGFILE") 2>&1

MODE="${1:---detect}"
CONFIRM="no"
REINSTALL_GLOBAL="no"
ALLOW_NO_LOCK="no"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) CONFIRM="yes" ;;
    --reinstall-global) REINSTALL_GLOBAL="yes" ;;
    --allow-no-lock) ALLOW_NO_LOCK="yes" ;;
    --detect|--fix) MODE="$1" ;;
    *) echo "[!] Неизвестный аргумент: $1"; echo "Использование: --detect | --fix [--yes] [--reinstall-global] [--allow-no-lock]"; exit 2 ;;
  esac; shift
done

command -v node >/dev/null || { echo "[!] Требуется node"; exit 2; }
command -v npm  >/dev/null || { echo "[!] Требуется npm";  exit 2; }

# --- Чёрный список (точные версии)
read -r -d '' AFFECTED_JSON <<'JSON'
{
  "ansi-styles": ["6.2.2"],
  "debug": ["4.4.2"],
  "chalk": ["5.6.1"],
  "supports-color": ["10.2.1"],
  "strip-ansi": ["7.1.1"],
  "ansi-regex": ["6.2.1"],
  "wrap-ansi": ["9.0.1"],
  "color-convert": ["3.1.1"],
  "color-name": ["2.0.1"],
  "is-arrayish": ["0.3.3"],
  "slice-ansi": ["7.1.1"],
  "color": ["5.0.1"],
  "color-string": ["2.1.1"],
  "simple-swizzle": ["0.2.3"],
  "supports-hyperlinks": ["4.1.1"],
  "has-ansi": ["6.0.1"],
  "chalk-template": ["1.1.1"],
  "backslash": ["0.2.1"],
  "@crowdstrike/commitlint": ["8.1.1", "8.1.2"],
  "@crowdstrike/falcon-shoelace": ["0.4.1", "0.4.2"],
  "@crowdstrike/foundry-js": ["0.19.1", "0.19.2"],
  "@crowdstrike/glide-core": ["0.34.2", "0.34.3"],
  "@crowdstrike/logscale-dashboard": ["1.205.1", "1.205.2"],
  "@crowdstrike/logscale-file-editor": ["1.205.1", "1.205.2"],
  "@crowdstrike/logscale-parser-edit": ["1.205.1", "1.205.2"],
  "@crowdstrike/logscale-search": ["1.205.1", "1.205.2"],
  "@crowdstrike/tailwind-toucan-base": ["5.0.1", "5.0.2"],
  "@art-ws/common": ["2.0.28"],
  "@art-ws/config-eslint": ["2.0.4", "2.0.5"],
  "@art-ws/config-ts": ["2.0.7", "2.0.8"],
  "@art-ws/db-context": ["2.0.24"],
  "@art-ws/di-node": ["2.0.13"],
  "@art-ws/di": ["2.0.28", "2.0.32"],
  "@art-ws/eslint": ["1.0.5", "1.0.6"],
  "@art-ws/fastify-http-server": ["2.0.24", "2.0.27"],
  "@art-ws/http-server": ["2.0.21", "2.0.25"],
  "@art-ws/openapi": ["0.1.9", "0.1.12"],
  "@art-ws/package-base": ["1.0.5", "1.0.6"],
  "@art-ws/prettier": ["1.0.5", "1.0.6"],
  "@art-ws/slf": ["2.0.15", "2.0.22"],
  "@art-ws/ssl-info": ["1.0.9", "1.0.10"],
  "@art-ws/web-app": ["1.0.3", "1.0.4"],
  "@ctrl/deluge": ["7.2.1", "7.2.2"],
  "@ctrl/golang-template": ["1.4.2", "1.4.3"],
  "@ctrl/magnet-link": ["4.0.3", "4.0.4"],
  "@ctrl/ngx-codemirror": ["7.0.1", "7.0.2"],
  "@ctrl/ngx-csv": ["6.0.1", "6.0.2"],
  "@ctrl/ngx-emoji-mart": ["9.2.1", "9.2.2"],
  "@ctrl/ngx-rightclick": ["4.0.1", "4.0.2"],
  "@ctrl/qbittorrent": ["9.7.1", "9.7.2"],
  "@ctrl/react-adsense": ["2.0.1", "2.0.2"],
  "@ctrl/shared-torrent": ["6.3.1", "6.3.2"],
  "@ctrl/tinycolor": ["4.1.1", "4.1.2"],
  "@ctrl/torrent-file": ["4.1.1", "4.1.2"],
  "@ctrl/transmission": ["7.3.1"],
  "@ctrl/ts-base32": ["4.0.1", "4.0.2"],
  "@hestjs/core": ["0.2.1"],
  "@hestjs/cqrs": ["0.1.6"],
  "@hestjs/demo": ["0.1.2"],
  "@hestjs/eslint-config": ["0.1.2"],
  "@hestjs/logger": ["0.1.6"],
  "@hestjs/scalar": ["0.1.7"],
  "@hestjs/validation": ["0.1.6"],
  "@nativescript-community/arraybuffers": ["1.1.6", "1.1.7", "1.1.8"],
  "@nativescript-community/gesturehandler": ["2.0.35"],
  "@nativescript-community/perms": ["3.0.5", "3.0.6", "3.0.7", "3.0.8"],
  "@nativescript-community/sentry": ["4.6.43"],
  "@nativescript-community/sqlite": ["3.5.2", "3.5.3", "3.5.4", "3.5.5"],
  "@nativescript-community/text": ["1.6.9", "1.6.10", "1.6.11", "1.6.12", "1.6.13"],
  "@nativescript-community/typeorm": ["0.2.30", "0.2.31", "0.2.32", "0.2.33"],
  "@nativescript-community/ui-collectionview": ["6.0.6"],
  "@nativescript-community/ui-document-picker": ["1.1.27", "1.1.28"],
  "@nativescript-community/ui-drawer": ["0.1.30"],
  "@nativescript-community/ui-image": ["4.5.6"],
  "@nativescript-community/ui-label": ["1.3.35", "1.3.36", "1.3.37"],
  "@nativescript-community/ui-material-bottom-navigation": ["7.2.72", "7.2.73", "7.2.74", "7.2.75"],
  "@nativescript-community/ui-material-bottomsheet": ["7.2.72"],
  "@nativescript-community/ui-material-core-tabs": ["7.2.72", "7.2.73", "7.2.74", "7.2.75", "7.2.76"],
  "@nativescript-community/ui-material-core": ["7.2.72", "7.2.73", "7.2.74", "7.2.75", "7.2.76"],
  "@nativescript-community/ui-material-ripple": ["7.2.72", "7.2.73", "7.2.74", "7.2.75"],
  "@nativescript-community/ui-material-tabs": ["7.2.72", "7.2.73", "7.2.74", "7.2.75"],
  "@nativescript-community/ui-pager": ["14.1.36", "14.1.37", "14.1.38"],
  "@nativescript-community/ui-pulltorefresh": ["2.5.4"],
  "@ahmedhfarag/ngx-perfect-scrollbar": ["20.0.20"],
  "@ahmedhfarag/ngx-virtual-scroller": ["4.0.4"]
}
JSON
export AFFECTED_JSON

# --- Контекст проекта / lock
IN_PROJECT="no"; LOCK_KIND="none"
if [[ -f "package.json" ]]; then
  IN_PROJECT="yes"
  if   [[ -f "pnpm-lock.yaml" ]]; then LOCK_KIND="pnpm-lock"
  elif [[ -f "yarn.lock"      ]]; then LOCK_KIND="yarn-lock"
  elif [[ -f "npm-shrinkwrap.json" ]]; then LOCK_KIND="npm-shrinkwrap"
  elif [[ -f "package-lock.json"   ]]; then LOCK_KIND="npm-lock"
  else
    LOCK_KIND="no-lock"
    echo "[!] Lock-файл не найден. Возможен дрейф зависимостей."
    [[ "$ALLOW_NO_LOCK" == "no" ]] && echo "    Добавьте --allow-no-lock, чтобы обновить без lock."
  fi
else
  echo "[i] package.json не найден. Локальная ремедиация будет пропущена."
fi

# --- Сканирование
echo "[-] Сканирую локальные и глобальные зависимости…"
REPORT="$(node - <<'NODE'
const { execFileSync } = require('child_process');
function safeLs(args){ try{ return JSON.parse(execFileSync('npm', args,{stdio:['ignore','pipe','ignore']}).toString()); }catch{ return {}; } }
function walk(t,a=[]){ if(!t||typeof t!=='object')return a; if(t.name&&t.version)a.push({name:t.name,version:t.version}); const d=t.dependencies||{}; for(const k of Object.keys(d))walk(d[k],a); return a; }
const A=JSON.parse(process.env.AFFECTED_JSON||'{}');
function hits(list){ const out=[]; for(const p of list||[]){ const bad=A[p.name]; if(bad&&bad.includes(p.version)) out.push(p); } return out; }
const local = hits(walk(safeLs(['ls','--all','--json'])));
const global= hits(walk(safeLs(['ls','-g','--all','--json'])));
process.stdout.write(JSON.stringify({localHits:local,globalHits:global}));
NODE
)"
export REPORT_JSON="$REPORT"

# --- Отчёт
node -e 'const r=JSON.parse(process.env.REPORT_JSON);
function p(t,a){ if(!a.length)return; console.log(`  ${t}:`); for(const x of a){console.log(`   - ${x.name}@${x.version}`);} }
if(!r.localHits.length && !r.globalHits.length) console.log("[+] Скомпрометированных версий не найдено. ✅");
else { console.log("[!] Обнаружены совпадения:"); p("LOCAL",r.localHits); p("GLOBAL",r.globalHits); }'

# --- Режимы
if [[ "$MODE" == "--detect" ]]; then
  [[ "$REPORT" =~ \"localHits\":\[{\  ]] || [[ "$REPORT" =~ \"globalHits\":\[{\  ]] && exit 1 || exit 0
fi
[[ "$MODE" != "--fix" ]] && { echo "[!] Используйте --detect или --fix"; exit 2; }

echo; echo "[*] Режим фикса. Lock-файлы не трогаем."

# --- Утилиты
confirm(){ [[ "$CONFIRM" == "yes" ]] && return 0; read -r -p "$1 [y/N] " a; [[ "${a,,}" == "y" || "${a,,}" == "yes" ]]; }

LOCAL_PKGS="$(node -e 'const r=JSON.parse(process.env.REPORT_JSON); console.log([...new Set(r.localHits.map(x=>x.name))].join(" "))')"
GLOBAL_PKGS="$(node -e 'const r=JSON.parse(process.env.REPORT_JSON); console.log([...new Set(r.globalHits.map(x=>x.name))].join(" "))')"

# --- Глобальные
GLOBAL_PREFIX="$(npm config get prefix || true)"
if [[ -n "$GLOBAL_PKGS" && "$GLOBAL_PREFIX" == *"$HOME"* ]]; then
  echo "[*] План глобальной очистки: $GLOBAL_PKGS"
  if confirm "→ Удалить глобальные пакеты?"; then
    npm uninstall -g $GLOBAL_PKGS || true
    [[ "$REINSTALL_GLOBAL" == "yes" ]] && npm i -g $(for p in $GLOBAL_PKGS; do printf "%s@latest " "$p"; done)
  fi
fi

# --- Локальные
if [[ "$IN_PROJECT" == "yes" && ( "$LOCK_KIND" != "no-lock" || "$ALLOW_NO_LOCK" == "yes" ) && -n "$LOCAL_PKGS" ]]; then
  echo "[*] План локального обновления: $LOCAL_PKGS"
  if confirm "→ Обновить локальные зависимости?"; then
    case "$LOCK_KIND" in
      npm-lock|npm-shrinkwrap) npm prune || true; npm dedupe || true; npm update $LOCAL_PKGS || true ;;
      yarn-lock)               yarn up $(for p in $LOCAL_PKGS; do printf "%s@latest " "$p"; done) ;;
      pnpm-lock)               pnpm update $LOCAL_PKGS --latest ;;
      no-lock)                 npm update $LOCAL_PKGS || true ;;
    esac
  fi
fi

echo; echo "[*] Рекомендуется пересоздать npm-токены и проверить SSH-ключи."
echo "[+] Готово."
