#!/bin/bash
set -euo pipefail

CRITICAL_BINARIES=(/bin/bash /usr/bin/ssh /usr/bin/sudo)

# --- function to check if command exists ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- docker/containers ---
collect_docker_info() {
    if command_exists docker; then
        jq -n \
          --argjson containers "$(docker ps -a --format '{{json .}}' | jq -s . 2>/dev/null || echo '[]')" \
          --argjson images    "$(docker images --format '{{json .}}' | jq -s . 2>/dev/null || echo '[]')" \
          --argjson networks  "$(docker network ls --format '{{json .}}' | jq -s . 2>/dev/null || echo '[]')" \
          --argjson volumes   "$(docker volume ls --format '{{json .}}' | jq -s . 2>/dev/null || echo '[]')" \
          '{containers: $containers, images: $images, networks: $networks, volumes: $volumes}'
    else
        echo '{"error": "docker not available"}'
    fi
}

# --- network configuration ---
collect_network_info() {
    local open_ports interfaces routes firewall
    open_ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $1, $5}' | jq -R -s -c 'split("\n")[:-1]')
    interfaces=$(ip -j a 2>/dev/null || echo '[]')
    routes=$(ip -j route 2>/dev/null || echo '[]')
    firewall=$(iptables-save 2>/dev/null | jq -R -s -c '.' || echo 'null')
    jq -n --argjson open_ports "$open_ports" --argjson interfaces "$interfaces" --argjson routes "$routes" --argjson firewall "$firewall" '{open_ports: $open_ports, interfaces: $interfaces, routes: $routes, firewall: $firewall}'
}

# --- service management ---
collect_services_info() {
    if command_exists systemctl; then
        running=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{print $1}' | jq -R -s -c 'split("\n")[:-1]')
        enabled=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | awk '{print $1}' | jq -R -s -c 'split("\n")[:-1]')
        jq -n --argjson running "$running" --argjson enabled "$enabled" '{running: $running, enabled: $enabled}'
    else
        echo '{"error": "systemctl not available"}'
    fi
}

# --- OS metadata ---
collect_os_info() {
    local os_release kernel hostname uptime env
    os_release=$(cat /etc/os-release 2>/dev/null | jq -R -s -c '.')
    kernel=$(uname -a 2>/dev/null | jq -R -c '.')
    hostname=$(hostname 2>/dev/null | jq -R -c '.')
    uptime=$(uptime -p 2>/dev/null | jq -R -c '.')
    env=$(env 2>/dev/null | jq -R -s -c '.')
    jq -n --arg os_release "$os_release" --arg kernel "$kernel" --arg hostname "$hostname" --arg uptime "$uptime" --arg env "$env" '{os_release: $os_release, kernel: $kernel, hostname: $hostname, uptime: $uptime, environment: $env}'
}

# --- user/group configs ---
collect_user_group_info() {
    users=$(cat /etc/passwd 2>/dev/null | jq -R -s -c '.')
    groups=$(cat /etc/group 2>/dev/null | jq -R -s -c '.')
    jq -n --arg users "$users" --arg groups "$groups" '{users: $users, groups: $groups}'
}

# --- scheduled Tasks ---
collect_scheduled_tasks() {
    crontab_user=$(crontab -l 2>/dev/null | jq -R -s -c '.')
    crontab_sys=$(cat /etc/crontab 2>/dev/null | jq -R -s -c '.')
    cron_hourly=$(ls /etc/cron.hourly 2>/dev/null | jq -R -s -c '.' || echo 'null')
    cron_daily=$(ls /etc/cron.daily 2>/dev/null | jq -R -s -c '.' || echo 'null')
    cron_weekly=$(ls /etc/cron.weekly 2>/dev/null | jq -R -s -c '.' || echo 'null')
    cron_monthly=$(ls /etc/cron.monthly 2>/dev/null | jq -R -s -c '.' || echo 'null')
    jq -n --arg crontab_user "$crontab_user" --arg crontab_sys "$crontab_sys" --arg cron_hourly "$cron_hourly" --arg cron_daily "$cron_daily" --arg cron_weekly "$cron_weekly" --arg cron_monthly "$cron_monthly" '{crontab_user: $crontab_user, crontab_sys: $crontab_sys, cron_hourly: $cron_hourly, cron_daily: $cron_daily, cron_weekly: $cron_weekly, cron_monthly: $cron_monthly}'
}

# --- integrity Checks ---
collect_integrity_info() {
    hashes=$(for bin in "${CRITICAL_BINARIES[@]}"; do
        if [ -f "$bin" ]; then
            echo -n "$bin:"
            sha256sum "$bin" | awk '{print $1}'
        fi
    done | jq -R -s -c 'split("\n")[:-1] | map(split(":")) | map({(.[0]): .[1]}) | add')
    jq -n --argjson hashes "$hashes" '{hashes: $hashes}'
}

# ---  metadata (timestamp, host, version) ---
collect_metadata() {
    jq -n \
      --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg hostname "$(hostname)" \
      --arg version "0.1.0" \
      '{timestamp: $timestamp, hostname: $hostname, tool_version: $version}'
}

main() {
    jq -n \
      --argjson metadata "$(collect_metadata)" \
      --argjson docker "$(collect_docker_info)" \
      --argjson network "$(collect_network_info)" \
      --argjson services "$(collect_services_info)" \
      --argjson os "$(collect_os_info)" \
      --argjson users_groups "$(collect_user_group_info)" \
      --argjson scheduled_tasks "$(collect_scheduled_tasks)" \
      --argjson integrity "$(collect_integrity_info)" \
      '{metadata: $metadata, docker: $docker, network: $network, services: $services, os: $os, users_groups: $users_groups, scheduled_tasks: $scheduled_tasks, integrity: $integrity}'
}

main "$@"
