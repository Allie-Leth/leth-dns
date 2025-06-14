#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────── CLI FLAGS ──────────────────────────
RUN_TESTS=false
while getopts ":t" opt; do
  case $opt in
    t) RUN_TESTS=true ;;
    *) echo "Usage: $0 [-t]"; exit 1 ;;
  esac
done
shift $((OPTIND-1))

# ───────────────────────── TEST MODE ───────────────────────────
# make sure bats is available (optional: auto-install)
if ! command -v bats >/dev/null 2>&1; then
  read -rp "Error: bats not found. Auto-install? (y/N): " ok
  if [[ "${ok,,}" == "y" ]]; then
    echo "Installing bats…"
    sudo apt-get update -qq
    sudo apt-get install -y bats
  else
    echo "Tests aborted — bats is required."
    docker compose down
    exit 1
  fi
fi

# bats is now guaranteed to exist
bats tests/
docker compose down
exit 0



# ───────────────────────── HELPERS ─────────────────────────────
read_default() { local v; read -rp "$1 [$2]: " v; printf '%s' "${v:-$2}"; }
prompt_secret() { local v; read -rsp "$1: " v && echo; printf '%s' "$v"; }
line() { printf '\n%s\n' "--------------------------------------------------------------"; }
select_number() {
  local prompt="$1" arr_name="$2" max idx
  eval "max=\${#${arr_name}[@]}"
  while true; do
    read -rp "$prompt [1-$max]: " idx
    [[ "$idx" =~ ^[0-9]+$ && idx -ge 1 && idx -le max ]] && { echo "$idx"; return; }
    echo "Invalid choice."
  done
}

echo "=== Pi-hole + Unbound bootstrap ==="

# ───────────── REGION / TIMEZONE PICK ─────────────
REGIONS=(Africa America Antarctica Arctic Asia Atlantic Australia Europe Indian Pacific)
echo "Select your region:"
for i in "${!REGIONS[@]}"; do printf "  %2d) %s\n" $((i+1)) "${REGIONS[i]}"; done
REGION=${REGIONS[$(select_number "Region" REGIONS)-1]}

declare -A MAJOR_TZS=(
  [Africa]="Cairo Lagos Johannesburg Nairobi Casablanca"
  [America]="New_York Chicago Denver Los_Angeles Phoenix"
  [Antarctica]="Palmer McMurdo"
  [Arctic]="Longyearbyen"
  [Asia]="Shanghai Tokyo Singapore Mumbai Dubai"
  [Atlantic]="Azores South_Georgia"
  [Australia]="Sydney Melbourne Perth Adelaide Canberra"
  [Europe]="London Berlin Paris Rome Madrid"
  [Indian]="Karachi Colombo"
  [Pacific]="Auckland Honolulu Guam"
)
IFS=' ' read -r -a CHOICES <<< "${MAJOR_TZS[$REGION]}"
ZONES=(); for c in "${CHOICES[@]}"; do ZONES+=("${REGION}/${c}"); done

echo; echo "Select your timezone in $REGION:"
for i in "${!ZONES[@]}"; do printf "  %2d) %s\n" $((i+1)) "${ZONES[i]#${REGION}/}"; done
TZ="${ZONES[$(select_number "Zone" ZONES)-1]}"

echo; echo "Chosen TZ: $TZ"; line

# ───────────── CONFIG MODE ─────────────
echo "Config mode:"
echo "  1) Default values (only password prompt)"
echo "  2) Custom (edit each variable)"
MODE=$(read_default "Select 1 or 2" "1")
MODE="${MODE//[[:space:]]/}"   # trim spaces
line

# ───────── DEFAULT VARS ─────────
declare -A V=(
  [TZ]="$TZ"
  [PIHOLE_IMAGE]="pihole/pihole"
  [PIHOLE_TAG]="2025.06.2"
  [PIHOLE_HOSTNAME]="pihole"
  [PIHOLE_DNS_SERVER]="127.0.0.1#5335"
  [UNBOUND_IMAGE]="mvance/unbound"
  [UNBOUND_TAG]="latest"
  [EXPORTER_IMAGE]="ekofr/pihole-exporter"
  [EXPORTER_TAG]="latest"
  [EXPORTER_PORT]="9617"
)

# ───────── DETECT ARM-COMPAT UNBOUND IMAGE ─────────
arch=$(uname -m)
UNBOUND_CANDIDATES=(
  "mvance/unbound ${V[UNBOUND_TAG]}"
  "crazymax/unbound ${V[UNBOUND_TAG]}"
)
for cand in "${UNBOUND_CANDIDATES[@]}"; do
  set -- $cand          # $1=image  $2=tag
  if timeout 8 docker manifest inspect "$1:$2" >/dev/null 2>&1 \
     && docker manifest inspect "$1:$2" | grep -q "\"$arch\"" ; then
    V[UNBOUND_IMAGE]="$1"; echo "Using Unbound image: $1:$2 (supports $arch)"; break
  fi
done
if [[ "$arch" =~ (arm64|aarch64) && ${V[UNBOUND_IMAGE]} == "mvance/unbound" ]]; then
  echo "No native arm64 Unbound image found—Docker will emulate via platform flag."
fi

# ───────── CUSTOM OVERRIDES ─────────
if [[ "$MODE" == "2" ]]; then
  V[PIHOLE_IMAGE]=$(read_default "Pi-hole image" "${V[PIHOLE_IMAGE]}")
  V[PIHOLE_TAG]=$(read_default "Pi-hole tag" "${V[PIHOLE_TAG]}")
  V[PIHOLE_HOSTNAME]=$(read_default "Pi-hole hostname" "${V[PIHOLE_HOSTNAME]}")
  V[PIHOLE_DNS_SERVER]=$(read_default "Upstream DNS" "${V[PIHOLE_DNS_SERVER]}")
  V[UNBOUND_IMAGE]=$(read_default "Unbound image"  "${V[UNBOUND_IMAGE]}")
  V[UNBOUND_TAG]=$(read_default "Unbound tag" "${V[UNBOUND_TAG]}")
  V[EXPORTER_IMAGE]=$(read_default "Exporter image" "${V[EXPORTER_IMAGE]}")
  V[EXPORTER_TAG]=$(read_default "Exporter tag" "${V[EXPORTER_TAG]}")
  V[EXPORTER_PORT]=$(read_default "Exporter port" "${V[EXPORTER_PORT]}")
fi

# ───────── PASSWORD ─────────
echo
if (( MODE == 1 )); then
  V[PIHOLE_WEBPASSWORD]=$(openssl rand -base64 18)
  echo "Generated password: ${V[PIHOLE_WEBPASSWORD]}"
else
  V[PIHOLE_WEBPASSWORD]=$(prompt_secret "Enter Pi-hole password")
fi
line

# ───────── PREVIEW ─────────
echo ".env will contain:"
for k in TZ PIHOLE_IMAGE PIHOLE_TAG PIHOLE_HOSTNAME PIHOLE_WEBPASSWORD PIHOLE_DNS_SERVER \
         UNBOUND_IMAGE UNBOUND_TAG EXPORTER_IMAGE EXPORTER_TAG EXPORTER_PORT; do
  printf '%-24s = %s\n' "$k" "${V[$k]}"
done
line
read -rp "Proceed? [y/N]: " ok
[[ "${ok,,}" == "y" ]] || { echo "Aborted."; exit 1; }

# ───────── WRITE .env & LAUNCH ─────────
{
  echo "# auto-generated on $(date)"
  for k in TZ PIHOLE_IMAGE PIHOLE_TAG PIHOLE_HOSTNAME PIHOLE_WEBPASSWORD PIHOLE_DNS_SERVER \
           UNBOUND_IMAGE UNBOUND_TAG EXPORTER_IMAGE EXPORTER_TAG EXPORTER_PORT; do
    echo "$k=${V[$k]}"
  done
} > .env

mkdir -p etc-pihole etc-dnsmasq.d unbound
docker compose pull
docker compose up -d
line
echo "Pi-hole UI : http://<Pi-IP>/"
echo "Username   : admin"
echo "Password   : ${V[PIHOLE_WEBPASSWORD]}"
line
