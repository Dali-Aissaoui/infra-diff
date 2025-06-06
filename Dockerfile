FROM debian:stable-slim


RUN apt-get update && apt-get install -y \
    bash \
    jq \
    curl \
    iproute2 \
    iputils-ping \
    iptables \
    systemctl \
    cron \
    docker.io \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /infra-diff

COPY snapshot.sh diff.sh alert.sh .env* ./

RUN chmod +x snapshot.sh diff.sh alert.sh

ENTRYPOINT ["/bin/bash"]

CMD ["-c", "echo 'Available commands: ./snapshot.sh, ./diff.sh, ./alert.sh' && ls -l *.sh"]
