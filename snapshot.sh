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
        tmp_containers=$(mktemp)
        tmp_images=$(mktemp)
        tmp_networks=$(mktemp)
        tmp_volumes=$(mktemp)
        docker ps -a --format '{{json .}}' | jq -s . 2>/dev/null > "$tmp_containers" || echo '[]' > "$tmp_containers"
        docker images --format '{{json .}}' | jq -s . 2>/dev/null > "$tmp_images" || echo '[]' > "$tmp_images"
        docker network ls --format '{{json .}}' | jq -s . 2>/dev/null > "$tmp_networks" || echo '[]' > "$tmp_networks"
        docker volume ls --format '{{json .}}' | jq -s . 2>/dev/null > "$tmp_volumes" || echo '[]' > "$tmp_volumes"
        jq -n \
          --slurpfile containers "$tmp_containers" \
          --slurpfile images "$tmp_images" \
          --slurpfile networks "$tmp_networks" \
          --slurpfile volumes "$tmp_volumes" \
          '{containers: $containers[0], images: $images[0], networks: $networks[0], volumes: $volumes[0]}'
        rm -f "$tmp_containers" "$tmp_images" "$tmp_networks" "$tmp_volumes"
    else
        echo '{"error": "docker not available"}'
    fi
}

# --- network configuration ---
collect_network_info() {
    tmp_ports=$(mktemp)
    tmp_interfaces=$(mktemp)
    tmp_routes=$(mktemp)
    tmp_firewall=$(mktemp)
    ss -tuln 2>/dev/null | awk 'NR>1 {print $1, $5}' | jq -R -s -c 'split("\n")[:-1]' > "$tmp_ports"
    ip -j a 2>/dev/null > "$tmp_interfaces" || echo '[]' > "$tmp_interfaces"
    ip -j route 2>/dev/null > "$tmp_routes" || echo '[]' > "$tmp_routes"
    iptables-save 2>/dev/null | jq -R -s -c '.' > "$tmp_firewall" || echo 'null' > "$tmp_firewall"
    jq -n \
      --slurpfile open_ports "$tmp_ports" \
      --slurpfile interfaces "$tmp_interfaces" \
      --slurpfile routes "$tmp_routes" \
      --slurpfile firewall "$tmp_firewall" \
      '{open_ports: $open_ports[0], interfaces: $interfaces[0], routes: $routes[0], firewall: $firewall[0]}'
    rm -f "$tmp_ports" "$tmp_interfaces" "$tmp_routes" "$tmp_firewall"
}

# --- service management ---
collect_services_info() {
    if command_exists systemctl; then
        tmp_running=$(mktemp)
        tmp_enabled=$(mktemp)
        systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{print $1}' | jq -R -s -c 'split("\n")[:-1]' > "$tmp_running"
        systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | awk '{print $1}' | jq -R -s -c 'split("\n")[:-1]' > "$tmp_enabled"
        jq -n \
          --slurpfile running "$tmp_running" \
          --slurpfile enabled "$tmp_enabled" \
          '{running: $running[0], enabled: $enabled[0]}'
        rm -f "$tmp_running" "$tmp_enabled"
    else
        echo '{"error": "systemctl not available"}'
    fi
}

# --- OS metadata ---
collect_os_info() {
    tmp_os_release=$(mktemp)
    tmp_kernel=$(mktemp)
    tmp_hostname=$(mktemp)
    tmp_uptime=$(mktemp)
    tmp_env=$(mktemp)
    cat /etc/os-release 2>/dev/null | jq -R -s -c '.' > "$tmp_os_release" || echo 'null' > "$tmp_os_release"
    uname -a 2>/dev/null | jq -R -c '.' > "$tmp_kernel" || echo 'null' > "$tmp_kernel"
    hostname 2>/dev/null | jq -R -c '.' > "$tmp_hostname" || echo 'null' > "$tmp_hostname"
    uptime -p 2>/dev/null | jq -R -c '.' > "$tmp_uptime" || echo 'null' > "$tmp_uptime"
    env 2>/dev/null | jq -R -s -c '.' > "$tmp_env" || echo 'null' > "$tmp_env"
    jq -n \
      --slurpfile os_release "$tmp_os_release" \
      --slurpfile kernel "$tmp_kernel" \
      --slurpfile hostname "$tmp_hostname" \
      --slurpfile uptime "$tmp_uptime" \
      --slurpfile env "$tmp_env" \
      '{os_release: $os_release[0], kernel: $kernel[0], hostname: $hostname[0], uptime: $uptime[0], environment: $env[0]}'
    rm -f "$tmp_os_release" "$tmp_kernel" "$tmp_hostname" "$tmp_uptime" "$tmp_env"
}

# --- user/group configs ---
collect_user_group_info() {
    tmp_users=$(mktemp)
    tmp_groups=$(mktemp)
    cat /etc/passwd 2>/dev/null | jq -R -s -c '.' > "$tmp_users" || echo 'null' > "$tmp_users"
    cat /etc/group 2>/dev/null | jq -R -s -c '.' > "$tmp_groups" || echo 'null' > "$tmp_groups"
    jq -n \
      --slurpfile users "$tmp_users" \
      --slurpfile groups "$tmp_groups" \
      '{users: $users[0], groups: $groups[0]}'
    rm -f "$tmp_users" "$tmp_groups"
}

# --- scheduled Tasks ---
collect_scheduled_tasks() {
    tmp_crontab_user=$(mktemp)
    tmp_crontab_sys=$(mktemp)
    tmp_cron_hourly=$(mktemp)
    tmp_cron_daily=$(mktemp)
    tmp_cron_weekly=$(mktemp)
    tmp_cron_monthly=$(mktemp)
    crontab -l 2>/dev/null | jq -R -s -c '.' > "$tmp_crontab_user" || echo 'null' > "$tmp_crontab_user"
    cat /etc/crontab 2>/dev/null | jq -R -s -c '.' > "$tmp_crontab_sys" || echo 'null' > "$tmp_crontab_sys"
    ls /etc/cron.hourly 2>/dev/null | jq -R -s -c '.' > "$tmp_cron_hourly" || echo 'null' > "$tmp_cron_hourly"
    ls /etc/cron.daily 2>/dev/null | jq -R -s -c '.' > "$tmp_cron_daily" || echo 'null' > "$tmp_cron_daily"
    ls /etc/cron.weekly 2>/dev/null | jq -R -s -c '.' > "$tmp_cron_weekly" || echo 'null' > "$tmp_cron_weekly"
    ls /etc/cron.monthly 2>/dev/null | jq -R -s -c '.' > "$tmp_cron_monthly" || echo 'null' > "$tmp_cron_monthly"
    jq -n \
      --slurpfile crontab_user "$tmp_crontab_user" \
      --slurpfile crontab_sys "$tmp_crontab_sys" \
      --slurpfile cron_hourly "$tmp_cron_hourly" \
      --slurpfile cron_daily "$tmp_cron_daily" \
      --slurpfile cron_weekly "$tmp_cron_weekly" \
      --slurpfile cron_monthly "$tmp_cron_monthly" \
      '{crontab_user: $crontab_user[0], crontab_sys: $crontab_sys[0], cron_hourly: $cron_hourly[0], cron_daily: $cron_daily[0], cron_weekly: $cron_weekly[0], cron_monthly: $cron_monthly[0]}'
    rm -f "$tmp_crontab_user" "$tmp_crontab_sys" "$tmp_cron_hourly" "$tmp_cron_daily" "$tmp_cron_weekly" "$tmp_cron_monthly"
}

# --- integrity Checks ---
collect_integrity_info() {
    tmp_hashes=$(mktemp)
    for bin in "${CRITICAL_BINARIES[@]}"; do
        if [ -f "$bin" ]; then
            echo -n "$bin:"
            sha256sum "$bin" | awk '{print $1}'
        fi
    done | jq -R -s -c 'split("\n")[:-1] | map(split(":")) | map({(.[0]): .[1]}) | add' > "$tmp_hashes"
    jq -n --slurpfile hashes "$tmp_hashes" '{hashes: $hashes[0]}'
    rm -f "$tmp_hashes"
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
    tmp_metadata=$(mktemp)
    tmp_docker=$(mktemp)
    tmp_network=$(mktemp)
    tmp_services=$(mktemp)
    tmp_os=$(mktemp)
    tmp_users_groups=$(mktemp)
    tmp_scheduled_tasks=$(mktemp)
    tmp_integrity=$(mktemp)

    collect_metadata > "$tmp_metadata"
    collect_docker_info > "$tmp_docker"
    collect_network_info > "$tmp_network"
    collect_services_info > "$tmp_services"
    collect_os_info > "$tmp_os"
    collect_user_group_info > "$tmp_users_groups"
    collect_scheduled_tasks > "$tmp_scheduled_tasks"
    collect_integrity_info > "$tmp_integrity"

    jq -n \
      --slurpfile metadata "$tmp_metadata" \
      --slurpfile docker "$tmp_docker" \
      --slurpfile network "$tmp_network" \
      --slurpfile services "$tmp_services" \
      --slurpfile os "$tmp_os" \
      --slurpfile users_groups "$tmp_users_groups" \
      --slurpfile scheduled_tasks "$tmp_scheduled_tasks" \
      --slurpfile integrity "$tmp_integrity" \
      '{
        metadata: $metadata[0],
        docker: $docker[0],
        network: $network[0],
        services: $services[0],
        os: $os[0],
        users_groups: $users_groups[0],
        scheduled_tasks: $scheduled_tasks[0],
        integrity: $integrity[0]
      }'

    rm -f "$tmp_metadata" "$tmp_docker" "$tmp_network" "$tmp_services" "$tmp_os" "$tmp_users_groups" "$tmp_scheduled_tasks" "$tmp_integrity"
}

main "$@"
