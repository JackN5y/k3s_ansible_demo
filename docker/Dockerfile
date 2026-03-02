FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git python3 python3-pip \
    iproute2 iptables iputils-ping \
    procps sudo ca-certificates \
    kmod \
    && rm -rf /var/lib/apt/lists/*

# Ansible + required collections
RUN pip3 install --no-cache-dir ansible
COPY ansible/requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml

# kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# Install dos2unix to strip Windows CRLF from copied files
RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/k3s-demo
COPY . .

# Normalize line endings for all text files (safe on Linux originals too)
RUN find /opt/k3s-demo -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.ini' -o -name '*.sh' \) -exec dos2unix {} +
