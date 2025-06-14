#!/usr/bin/env bash
set -euo pipefail

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
echo "Select your region:"; for i in "${!REGIONS[@]}"; do printf "  %2d) %s\n" $((i+1)) "${REGIONS[i]}"; done
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
echo; echo "Select your timezone in $REGION:"; for i in "${!ZONES[@]}"; do printf "  %2d) %s\n" $((i+1)) "${ZONES[i]#${REGION}/}"; done
TZ="${ZONES[$(select_number "Zone" ZONES)-1]}"

echo; echo "Chosen TZ: $TZ"; line

# ─── ask for your Pi-hole UI alias ───
DNS_UI_ALIAS=$(read_default "Enter the DNS alias for Pi-hole UI" "dns.ls")
# strip surrounding whitespace and a single leading dot, nothing more
DNS_UI_ALIAS="$(echo "$DNS_UI_ALIAS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^\.//')"

# ───────────── CONFIG MODE ─────────────
echo "Config mode:"; echo "  1) Default values (auto-generated password)"; echo "  2) Custom values"
MODE=$(read_default "Select 1 or 2" "1"); MODE=${MODE//[[:space:]]/}; line

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

# ───────── CUSTOM OVERRIDES ─────────
if [[ "$MODE" == "2" ]]; then
  for k in PIHOLE_IMAGE PIHOLE_TAG PIHOLE_HOSTNAME PIHOLE_DNS_SERVER \
           UNBOUND_IMAGE UNBOUND_TAG EXPORTER_IMAGE EXPORTER_TAG EXPORTER_PORT; do
    V[$k]=$(read_default "$k" "${V[$k]}")
  done
fi

# ───────── password ─────────
echo
V[PIHOLE_WEBPASSWORD]=$(openssl rand -base64 18)
echo "Generated password: ${V[PIHOLE_WEBPASSWORD]}"; line

# ───────── preview & confirm ─────────
echo ".env will contain:"; for k in "${!V[@]}"; do printf '%-24s = %s\n' "$k" "${V[$k]}"; done; line
read -rp "Proceed? [y/N]: " ok; [[ "${ok,,}" == "y" ]] || { echo "Aborted."; exit 1; }

# ───────── write env & launch ─────────
{ echo "# auto-generated $(date)"; for k in "${!V[@]}"; do echo "$k=${V[$k]}"; done; } > .env

# ─── autodetect host IP and serve pihole.ls via Pi-hole ───
# (so https://pihole.ls/admin will resolve to your Pi’s IP)
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null \
           | awk '/src/ { for(i=1;i<=NF;i++) if($i=="src") print $(i+1) }')
echo "address=/${DNS_UI_ALIAS}/${HOST_IP:-127.0.0.1}" \
  > etc-dnsmasq.d/02-local-${DNS_UI_ALIAS}.conf

mkdir -p etc-pihole etc-dnsmasq.d unbound
docker compose pull
docker compose up -d
line
echo "Pi-hole UI : https://${DNS_UI_ALIAS}/admin"
echo "Username   : admin"
echo "Password   : ${V[PIHOLE_WEBPASSWORD]}"
line
