# LethStack - DNS Module


Self‑hosted, drop‑in DNS for the Leth-Stack homelab.

* **Pi‑hole** - network‑wide ad blocking & local records
* **Unbound** - DNSSEC‑validating recursion
* **Exporter** - optional Prometheus metrics (minimal footprint)

---

## Services

| Service    | Ports              | Notes                                  |
| ---------- | ------------------ | -------------------------------------- |
| Pi‑hole    | 53 UDP/TCP, 80 TCP | Web UI & sink‑hole                     |
| Unbound    | 5335 UDP           | Recursive resolver                     |
| Exporter\* | 9617 TCP           | Disable if you don’t scrape Prometheus |

---

## Quick start

### A) Guided script

```bash
./run.sh          # wizard (TZ picker, .env, docker pull)
```

### B) Manual compose

```bash
cp .env.example .env   # set TZ + password
mkdir -p etc-pihole etc-dnsmasq.d unbound
docker compose pull
docker compose up -d
```

Login -> `http://<pi-ip>/` (user **admin**, pwd in `.env`).
Router DHCP -> set **DNS 1** to Pi‑hole IP.

---

## Prometheus (optional)

If you already scrape metrics elsewhere:

```text
job_name: lethstack
static_configs:
  - targets: ['<pi-ip>:9617']
```

Grafana dashboard ID **11074** works out‑of‑the‑box.

---

## Backup

```bash
tar czf lethstack-$(date +%F).tgz \
  etc-pihole etc-dnsmasq.d unbound
```

Restore -> untar into repo root, then `docker compose up -d`.

---

