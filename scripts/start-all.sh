#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

START_ALL_SELECT="${START_ALL_SELECT:-1}"
START_ALL_COMPONENTS="${START_ALL_COMPONENTS:-}"
START_ALL_NPM_CI="${START_ALL_NPM_CI:-auto}"
START_ALL_MIGRATE="${START_ALL_MIGRATE:-1}"
START_ALL_UI="${START_ALL_UI:-1}"
START_ALL_REPORTING="${START_ALL_REPORTING:-0}"
START_ALL_TAZAMA="${START_ALL_TAZAMA:-0}"
START_ALL_PPA="${START_ALL_PPA:-0}"

usage() {
  cat <<'EOF'
Usage: local/scripts/start-all.sh [--select|--all]

Default opens an interactive checklist.

Options:
  --select, -s    Open an interactive checklist.
  --all, -a       Start the normal full stack without a checklist.
  --help, -h      Show this help.

Environment:
  START_ALL_SELECT=0
  START_ALL_COMPONENTS=infra,deps,migrations,core,wallet1,wallet2,ui
  START_ALL_NPM_CI=auto|always|skip
  START_ALL_MIGRATE=0
  START_ALL_UI=0
  START_ALL_REPORTING=1
  START_ALL_TAZAMA=1
  START_ALL_PPA=1

Components:
  infra       MariaDB, Valkey, Kafka, topics, baseline DB provisioning
  deps        Core npm dependencies
  migrations  Core DB migrations and ledger reference data
  core        Mojaloop core services
  wallet1     wallet1 DemoWallet, Pivotal apps, connector, onboarding
  wallet2     wallet2 DemoWallet, Pivotal apps, connector, onboarding
  ui          Local monitor UI
  reporting   Optional reporting stack
  tazama      Optional Tazama service
  ppa         Optional payment platform adapter
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --select|-s)
      START_ALL_SELECT=1
      ;;
    --all|-a|--no-select)
      START_ALL_SELECT=0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

step() {
  echo
  echo "==> $*"
  "$@"
}

validate_npm_ci_mode() {
  case "$START_ALL_NPM_CI" in
    auto|always|skip)
      ;;
    *)
      echo "Invalid START_ALL_NPM_CI=$START_ALL_NPM_CI. Use auto, always, or skip." >&2
      exit 1
      ;;
  esac
}

core_dependencies_missing() {
  local repo

  for repo in central-ledger account-lookup-service ml-api-adapter quoting-service central-settlement; do
    if [ ! -d "$ROOT_DIR/$repo/node_modules" ]; then
      return 0
    fi
  done

  return 1
}

maybe_install_core_dependencies() {
  case "$START_ALL_NPM_CI" in
    auto)
      if core_dependencies_missing; then
        step "$LOCAL_HOME/scripts/npm-ci-all.sh"
      else
        echo
        echo "==> Core npm dependencies already installed"
      fi
      ;;
    always)
      step "$LOCAL_HOME/scripts/npm-ci-all.sh"
      ;;
    skip)
      echo
      echo "==> Skipping core npm install"
      ;;
  esac
}

default_components() {
  local components=(infra deps)

  if [ "$START_ALL_MIGRATE" = "1" ]; then
    components+=(migrations)
  fi

  components+=(core wallet1 wallet2)

  if [ "$START_ALL_UI" = "1" ]; then
    components+=(ui)
  fi

  if [ "$START_ALL_REPORTING" = "1" ]; then
    components+=(reporting)
  fi
  if [ "$START_ALL_TAZAMA" = "1" ]; then
    components+=(tazama)
  fi
  if [ "$START_ALL_PPA" = "1" ]; then
    components+=(ppa)
  fi

  printf '%s\n' "${components[*]}"
}

choose_components() {
  local result
  local migrations_state="ON"
  local ui_state="ON"
  local reporting_state="OFF"
  local tazama_state="OFF"
  local ppa_state="OFF"
  local dialog_migrations_state="on"
  local dialog_ui_state="on"
  local dialog_reporting_state="off"
  local dialog_tazama_state="off"
  local dialog_ppa_state="off"

  if [ "$START_ALL_MIGRATE" != "1" ]; then
    migrations_state="OFF"
    dialog_migrations_state="off"
  fi
  if [ "$START_ALL_UI" != "1" ]; then
    ui_state="OFF"
    dialog_ui_state="off"
  fi
  if [ "$START_ALL_REPORTING" = "1" ]; then
    reporting_state="ON"
    dialog_reporting_state="on"
  fi
  if [ "$START_ALL_TAZAMA" = "1" ]; then
    tazama_state="ON"
    dialog_tazama_state="on"
  fi
  if [ "$START_ALL_PPA" = "1" ]; then
    ppa_state="ON"
    dialog_ppa_state="on"
  fi

  if command -v whiptail >/dev/null 2>&1; then
    if ! result="$(
      whiptail \
        --title "Start Local Mojaloop Stack" \
        --checklist "Select components to start:" \
        24 92 12 \
        infra "Infrastructure: MariaDB, Valkey, Kafka, topics" ON \
        deps "Core npm dependencies (${START_ALL_NPM_CI})" ON \
        migrations "Core DB migrations and ledger reference data" "$migrations_state" \
        core "Mojaloop core services" ON \
        wallet1 "wallet1 DemoWallet + Pivotal + connector + onboarding" ON \
        wallet2 "wallet2 DemoWallet + Pivotal + connector + onboarding" ON \
        ui "Local monitor UI" "$ui_state" \
        reporting "Optional reporting stack" "$reporting_state" \
        tazama "Optional Tazama service" "$tazama_state" \
        ppa "Optional payment platform adapter" "$ppa_state" \
        3>&1 1>&2 2>&3
    )"; then
      echo "Selection cancelled." >&2
      exit 1
    fi
  elif command -v dialog >/dev/null 2>&1; then
    if ! result="$(
      dialog \
        --title "Start Local Mojaloop Stack" \
        --checklist "Select components to start:" \
        24 92 12 \
        infra "Infrastructure: MariaDB, Valkey, Kafka, topics" on \
        deps "Core npm dependencies (${START_ALL_NPM_CI})" on \
        migrations "Core DB migrations and ledger reference data" "$dialog_migrations_state" \
        core "Mojaloop core services" on \
        wallet1 "wallet1 DemoWallet + Pivotal + connector + onboarding" on \
        wallet2 "wallet2 DemoWallet + Pivotal + connector + onboarding" on \
        ui "Local monitor UI" "$dialog_ui_state" \
        reporting "Optional reporting stack" "$dialog_reporting_state" \
        tazama "Optional Tazama service" "$dialog_tazama_state" \
        ppa "Optional payment platform adapter" "$dialog_ppa_state" \
        3>&1 1>&2 2>&3
    )"; then
      echo "Selection cancelled." >&2
      exit 1
    fi
  else
    echo "No whiptail/dialog found. Enter comma-separated components." > /dev/tty
    echo "Default: infra,deps,migrations,core,wallet1,wallet2,ui" > /dev/tty
    read -r -p "Components: " result < /dev/tty
  fi

  result="${result//\"/}"
  result="${result//$'\n'/ }"
  result="${result// /,}"
  START_ALL_COMPONENTS="${result}"
}

normalize_components() {
  local raw="$1"
  local item

  raw="${raw//,/ }"
  SELECTED_COMPONENTS=()

  for item in $raw; do
    case "$item" in
      infra|deps|migrations|core|wallet1|wallet2|ui|reporting|tazama|ppa)
        SELECTED_COMPONENTS+=("$item")
        ;;
      "")
        ;;
      *)
        echo "Unknown START_ALL component: $item" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if [ "${#SELECTED_COMPONENTS[@]}" -eq 0 ]; then
    echo "No start-all components selected." >&2
    exit 1
  fi
}

component_enabled() {
  local wanted="$1"
  local item

  for item in "${SELECTED_COMPONENTS[@]}"; do
    if [ "$item" = "$wanted" ]; then
      return 0
    fi
  done

  return 1
}

validate_npm_ci_mode

if [ "$START_ALL_SELECT" = "1" ] && [ -z "$START_ALL_COMPONENTS" ]; then
  choose_components
fi

if [ -z "$START_ALL_COMPONENTS" ]; then
  START_ALL_COMPONENTS="$(default_components)"
fi

normalize_components "$START_ALL_COMPONENTS"

echo "Selected components: ${SELECTED_COMPONENTS[*]}"

if component_enabled infra; then
  step "$LOCAL_HOME/scripts/start-infra.sh"
fi

if component_enabled deps; then
  maybe_install_core_dependencies
fi

if component_enabled migrations; then
  step "$LOCAL_HOME/scripts/migrate-all.sh"
fi

if component_enabled core; then
  step "$LOCAL_HOME/scripts/start-mojaloop-core-services.sh"
fi

if component_enabled wallet1; then
  step "$LOCAL_HOME/scripts/start-wallet1-services.sh"
  step "$LOCAL_HOME/scripts/onboard-wallet1.sh"
fi

if component_enabled wallet2; then
  step "$LOCAL_HOME/scripts/start-wallet2-services.sh"
  step "$LOCAL_HOME/scripts/onboard-wallet2.sh"
fi

if component_enabled ui; then
  step "$LOCAL_HOME/scripts/start-ui.sh"
fi

if component_enabled reporting; then
  step "$LOCAL_HOME/scripts/start-reporting-stack.sh"
fi

if component_enabled tazama; then
  step "$LOCAL_HOME/scripts/start-tazama.sh"
fi

if component_enabled ppa; then
  step "$LOCAL_HOME/scripts/start-ppa.sh"
fi

cat <<EOF

Local stack started.

Core:
- ML API Adapter: http://127.0.0.1:3000
- Central Ledger: http://127.0.0.1:3001
- Quoting: http://127.0.0.1:3002
- Account Lookup: http://127.0.0.1:4002

Pivotal:
- Web Outbound: http://127.0.0.1:3200
- Web Inbound: http://127.0.0.1:3201
- Portal API: http://127.0.0.1:3202
- Portal UI: http://127.0.0.1:4173

Local monitor:
- http://127.0.0.1:${LOCAL_UI_PORT:-3400}
EOF
