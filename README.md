# k3s + ArgoCD — single-node cluster bootstrap

Ansible-based automation that sets up a production-like Kubernetes environment on a single Linux machine:

- **k3s** single-node cluster
- **ArgoCD** for GitOps-style continuous deployment
- **nginx** as a sample web application exposed via NodePort
- **sysctl** network tunables applied automatically

---

## How it works

```
GitHub repo (gitops/manifests/)
       │
       │  ArgoCD auto-sync (on every git push)
       ▼
  k3s cluster
  └── webapp namespace
       └── nginx Deployment (2 replicas)
            └── Service NodePort :30080
```

ArgoCD continuously watches the `gitops/manifests/` directory in this repository.
Every `git push` automatically triggers a sync to the cluster — no manual `kubectl apply` needed.

---

## Repository structure

```
.
├── ansible/
│   ├── site.yml              # main playbook — installs k3s + ArgoCD
│   ├── requirements.yml      # Ansible Galaxy collections
│   └── hosts.ini.example     # inventory template
├── gitops/                   # everything ArgoCD watches and manages
│   ├── manifests/            # Kubernetes manifests — synced by ArgoCD
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml   # nginx, 2 replicas
│   │   └── service.yaml      # NodePort 30080
│   └── argocd/
│       └── application.yaml  # ArgoCD Application resource
└── docker/
    ├── Dockerfile             # Ubuntu + Ansible + kubectl
    ├── docker-compose.yml
    └── hosts.ini              # Ansible inventory (localhost inside container)
```

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed (Docker Desktop on Windows/Mac, Docker Engine on Linux)

That's it. No Ansible, no Python, no kubectl needed on your machine.

---

## Quick start

```bash
git clone https://github.com/JackN5y/k3s_ansible_demo.git
cd k3s_ansible_demo/docker

docker compose up --build
```

Docker will build the image, run the Ansible playbook inside the container, and print at the end:

```
ArgoCD URL  : https://localhost:30443  (user: admin)
nginx app   : http://localhost:30080
```

**Other commands:**

```bash
# Rebuild the image from scratch
docker compose up --build --force-recreate

# Open a shell inside the running container
docker exec -it k3s-argocd-node bash

# Stop and remove everything
docker compose down -v
```

---

## Ports

| Port | Service |
|------|---------|
| `30080` | nginx — http://localhost:30080 |
| `30443` | ArgoCD UI — https://localhost:30443 |
| `6443` | k3s API server |

---

## What the playbook does

| Tag | Step | Details |
|-----|------|---------|
| `sysctl` | Network tunables | `ip_forward=1`, `br_netfilter=1`, `somaxconn=65535`, `netdev_max_backlog=5000`, `ip_local_port_range=1024-65535`, `tcp_keepalive_time=300`, `tcp_max_syn_backlog=8192` |
| `k3s` | Install k3s | Official install script, version pinned, Traefik disabled, systemd service enabled |
| `argocd` | Install ArgoCD | Official `install.yaml` manifest, argocd-server exposed as NodePort 30443, argocd CLI installed |
| `argocd_app` | Apply Application | Applies `gitops/argocd/application.yaml`; ArgoCD begins auto-syncing `gitops/manifests/` from GitHub |

---

## Verify the deployment

```bash
# inside the container
docker exec -it k3s-argocd-node bash

kubectl get nodes
kubectl get pods -A
kubectl get svc  -n webapp
kubectl get app  webapp -n argocd
```

---

## Configuration reference

Key variables in [ansible/site.yml](ansible/site.yml):

| Variable | Default | Description |
|----------|---------|-------------|
| `k3s_version` | `v1.29.3+k3s1` | k3s release to install |
| `argocd_version` | `v2.10.3` | ArgoCD release to install |
| `argocd_repo_url` | `https://github.com/JackN5y/k3s_ansible_demo.git` | Git repo ArgoCD syncs from |
| `argocd_namespace` | `argocd` | Namespace for ArgoCD components |
| `webapp_namespace` | `webapp` | Namespace for the nginx application |
