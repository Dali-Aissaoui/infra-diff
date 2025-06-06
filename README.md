# infra-diff: Infrastructure Snapshot & Drift Detection

## Overview

**infra-diff** is a modular, container-ready Bash toolkit for infrastructure snapshotting, drift detection, and alerting. It captures detailed system state, detects changes over time, and can send webhook alerts on drift.

---

## Quick Start

### 1. Clone the Repository

```sh
git clone <your-repo-url>
cd infra-diff
```

### 2. Configure Environment Variables

- Copy `.env.example` to `.env` and set your values:
  ```sh
  cp .env.example .env
  # Edit .env to set WEBHOOK_URL, INTERVAL, SNAPSHOT_DIR, etc.
  ```

---

## Running on a VPS (Host)

### **Install Dependencies**

```sh
sudo apt-get update && sudo apt-get install -y bash jq curl iproute2 iputils-ping iptables systemctl cron docker.io procps net-tools
```

### **Make Scripts Executable**

```sh
chmod +x snapshot.sh diff.sh alert.sh entrypoint.sh
```

### **Run Once**

```sh
./snapshot.sh > snapshot.json
```

### **Run Periodically (every INTERVAL seconds)**

```sh
./entrypoint.sh
```

- Snapshots and diffs will be stored in the `SNAPSHOT_DIR` (default: `./snapshots` or as set in `.env`).
- Alerts are sent to your `WEBHOOK_URL` if drift is detected.

---

## Running in Docker

### **Build the Image**

```sh
docker build -t infra-diff .
```

### **Run the Container (with host Docker socket):**

```sh
docker run --rm \
  -v "$PWD:/infra-diff" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  infra-diff ./entrypoint.sh
```

- The above mounts your project directory (for `.env`, snapshots, etc.) and the Docker socket (for host container info).
- Snapshots and diffs will appear in your mounted `SNAPSHOT_DIR`.

### **Notes:**

- If you do **not** mount `/var/run/docker.sock`, the Docker section will only see containers inside the container (usually none).
- To snapshot your VPS including its Docker state, run on the host or mount the socket.

---

## Environment Variables

| Variable     | Description                                   | Example                     |
| ------------ | --------------------------------------------- | --------------------------- |
| WEBHOOK_URL  | Webhook endpoint for drift alerts (required)  | https://example.com/webhook |
| INTERVAL     | Interval between runs (seconds, default: 300) | 60                          |
| SNAPSHOT_DIR | Directory for snapshots/diffs                 | ./snapshots                 |

- Set these in `.env` or pass as `-e` arguments to Docker.

---

TMP=$(mktemp)
echo '{"foo": 1}' > "$TMP"
jq -n --slurpfile data "$TMP" '{data: $data[0]}'
rm -f "$TMP"
```

---

## Troubleshooting

- **Permission denied**: Ensure scripts are executable (`chmod +x ...`).
- **jq: Argument list too long**: This is solved by using temp files and `--slurpfile`.
- **No Docker info**: If running in Docker, mount the host Docker socket.
- **No alerts**: Check your `WEBHOOK_URL` and network connectivity.

---

## Contributing & License

Pull requests welcome! Please open issues for bugs or suggestions.

---

## Credits

Developed by Aissaoui Med Ali.
