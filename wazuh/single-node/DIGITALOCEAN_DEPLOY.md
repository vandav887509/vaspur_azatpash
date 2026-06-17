# Deploying Wazuh (Docker, single-node) on a DigitalOcean Droplet

This guide deploys the official Wazuh 4.14.5 single-node Docker stack
(manager + indexer + dashboard) on a DigitalOcean droplet. The
`docker-compose.yml` and `config/` files here are unmodified from the
official [wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker)
repository at tag `v4.14.5`.

## 1. Create the droplet

Wazuh's indexer (OpenSearch) is memory-hungry, so don't go too small —
under-provisioning will cause crashes or extremely slow startup.

| Use case | Minimum size |
|---|---|
| Testing / personal lab | 4 GB RAM / 2 vCPU |
| Light production use | 8 GB RAM / 4 vCPU |

Recommended droplet settings:
- **Image:** Ubuntu 24.04 LTS
- **Region:** closest to you or your monitored endpoints
- **Authentication:** SSH key (not password)

Check current DigitalOcean pricing/specs in their console, since these
change over time.

## 2. Bootstrap the droplet

SSH into the new droplet, copy this whole `wazuh/single-node` directory
over (e.g. `git clone` your repo, or `scp`), then run:

```bash
cd wazuh/single-node
sudo bash setup-droplet.sh
```

This installs Docker + the Compose plugin, sets the
`vm.max_map_count` kernel parameter the indexer requires, and opens
only the ports Wazuh actually needs (443 for the dashboard, 1514/1515
for agents) via UFW — it deliberately leaves the indexer (9200) and
API (55000) ports closed to the public internet.

## 3. Generate certificates

```bash
docker compose -f generate-indexer-certs.yml run --rm generator
```

## 4. ⚠️ Change the default credentials before going further

The stock `docker-compose.yml` ships with well-known default
passwords (`SecretPassword`, `kibanaserver`, `MyS3cr37P450r.*-`).
These are public knowledge from the Wazuh documentation, so leaving
them as-is on an internet-facing droplet is a real exposure. Before
starting the stack, edit `docker-compose.yml` and replace:

- `INDEXER_PASSWORD` (appears in `wazuh.manager` and `wazuh.dashboard`)
- `API_PASSWORD` (appears in `wazuh.manager` and `wazuh.dashboard`)
- `DASHBOARD_PASSWORD`

with strong, unique values — and use the **same** new value everywhere
each variable appears, since the services authenticate to each other
with these.

## 5. Start the stack

```bash
docker compose up -d
```

First boot takes roughly a minute while the indexer initializes.
Check status with:

```bash
docker compose ps
```

## 6. Access the dashboard

Open `https://<your-droplet-ip>` in a browser. The certificate is
self-signed, so your browser will warn you — that's expected for this
setup; click through to accept it, or put a reverse proxy with a real
certificate (e.g. Let's Encrypt via Caddy or nginx) in front of it
later if you want to avoid that.

Log in with the dashboard credentials you set in step 4
(`admin` / your new `INDEXER_PASSWORD`).

## 7. Connecting agents

Install the Wazuh agent on whatever hosts you want monitored and point
it at `<your-droplet-ip>` on port 1514/1515. See the
[Wazuh agent installation docs](https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html)
for your OS.

## Notes

- This is a **single-node** deployment: one manager, one indexer, one
  dashboard, all on one droplet. Fine for testing or small
  deployments; not horizontally scaled.
- Data persists in Docker volumes, so `docker compose down` (without
  `-v`) and `docker compose up -d` again won't lose your alerts/config.
- To upgrade later, see the
  [official upgrade guide](https://documentation.wazuh.com/current/deployment-options/docker/upgrading-wazuh-docker.html).
