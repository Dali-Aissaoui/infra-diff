# infra-diff: Infrastructure Snapshot & Drift Detection

## Overview

**infra-diff** is a modular, container-ready Bash toolkit for infrastructure snapshotting, drift detection, and alerting. It captures detailed system state (including Docker, network, services, users, scheduled tasks, and more), detects changes over time, and can send webhook alerts on drift. Designed for both VPS (host) and Dockerized environments, it features robust error handling, JSON output, and easy scheduling.

---

## Features

- **Comprehensive Snapshots**: Captures Docker, network, OS, users/groups, cron, and file integrity info as JSON.
- **Drift Detection**: Compares snapshots, outputs categorized diffs.
- **Webhook Alerting**: Sends POST requests with drift details to a configurable webhook.
- **Containerized & Host Support**: Runs natively on VPS or inside Docker (with host Docker socket).
- **Automated Scheduling**: Orchestrator script (`entrypoint.sh`) supports periodic runs.
- **Robust & Scalable**: Handles large outputs efficiently using temp files and `jq --slurpfile`.

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

## Directory Structure

```
infra-diff/
├── snapshot.sh        # Collects system snapshot as JSON
├── diff.sh            # Compares two snapshots, outputs drift
├── alert.sh           # Sends webhook alert if drift detected
├── entrypoint.sh      # Orchestrates periodic snapshot/diff/alert
├── Dockerfile         # Container build
├── .env               # Your environment config (not committed)
├── .env.example       # Example env config
├── snapshots/         # (default) Snapshots & diffs (gitignored)
└── ...
```

---

## mktemp: What & Why

`mktemp` is a Unix command that creates a unique temporary file or directory. In this project, it's used to:

- **Safely handle large outputs**: Instead of passing big data as shell arguments (which can hit system limits and cause errors), each collector writes its JSON to a temp file.
- **Efficiently assemble JSON**: The main script then loads these temp files into `jq` using `--slurpfile`, ensuring robust and scalable processing.
- **Automatic cleanup**: Temp files are deleted after use, keeping your system tidy.

**Example:**

```bash
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
