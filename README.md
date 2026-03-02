# k3s + ArgoCD — single-node cluster bootstrap

Ansible-based automation that sets up a production-like Kubernetes environment on a single Linux machine:

- **k3s** single-node cluster
- **ArgoCD** for GitOps-style continuous deployment
- **nginx** as a sample web application exposed via NodePort
- **sysctl** network tunables applied automatically

---

## Repository structure

```
.
├── ansible/
│   ├── site.yml              # main playbook
│   ├── requirements.yml      # Ansible Galaxy collections
│   └── hosts.ini.example     # inventory template
├── manifests/                # Kubernetes manifests (synced by ArgoCD)
│   ├── namespace.yaml
│   ├── deployment.yaml       # nginx, 2 replicas
│   └── service.yaml          # NodePort 30080
├── argocd/
│   └── application.yaml      # ArgoCD Application resource
└── docker/                   # Optional: run everything in Docker on Windows
    ├── Dockerfile
    ├── docker-compose.yml
    └── run.ps1
```

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Linux (Ubuntu 22.04 / Debian 12 / RHEL 9) | target machine |
| Python 3.8+ | on target |
| Ansible 2.15+ | on control node |
| Internet access | to download k3s, ArgoCD, container images |

---

## Quick start

### 1. Clone and configure

```bash
git clone https://github.com/JackN5y/k3s_ansible_demo.git
cd k3s_ansible_demo

# Install required Ansible collections
ansible-galaxy collection install -r ansible/requirements.yml

# Create inventory from template
cp ansible/hosts.ini.example ansible/hosts.ini
# Edit hosts.ini if targeting a remote machine
```

### 2. Set your repository URL

The repository URL is already configured in [argocd/application.yaml](argocd/application.yaml):

```yaml
repoURL: https://github.com/JackN5y/k3s_ansible_demo.git
```

### 3. Run the playbook

```bash
ansible-playbook -i ansible/hosts.ini ansible/site.yml
```

The playbook will print a summary at the end:

```
ArgoCD URL  : https://<node-ip>:30443
Username    : admin
Password    : <generated>
nginx app   : http://<node-ip>:30080
```

---

## What the playbook does (step by step)

| Tag | Step | Details |
|-----|------|---------|
| `sysctl` | Network tunables | `ip_forward`, `br_netfilter`, `somaxconn=65535`, `netdev_max_backlog=5000`, `ip_local_port_range=1024-65535`, `tcp_keepalive_time=300`, `tcp_max_syn_backlog=8192` |
| `k3s` | Install k3s | Official install script, version pinned via `k3s_version`, Traefik disabled, systemd service enabled |
| `argocd` | Install ArgoCD | Official `install.yaml` manifest, argocd-server exposed as NodePort 30443, argocd CLI installed |
| `argocd_app` | Apply Application | Copies `argocd/application.yaml` and applies it; ArgoCD starts auto-syncing `manifests/` |

Run individual steps with `--tags`:

```bash
ansible-playbook -i ansible/hosts.ini ansible/site.yml --tags sysctl
ansible-playbook -i ansible/hosts.ini ansible/site.yml --tags k3s,argocd
```

---

## ArgoCD Application

[argocd/application.yaml](argocd/application.yaml) configures ArgoCD to:

- Watch the `manifests/` directory in this repository
- Auto-sync on every commit (`automated.selfHeal: true`)
- Prune resources removed from git (`prune: true`)
- Retry failed syncs up to 5 times with exponential backoff

---

## Running on Windows (Docker)

If you are on Windows, use the Docker helper to simulate a Linux machine:

```powershell
cd docker
Set-ExecutionPolicy -Scope Process RemoteSigned
.\run.ps1          # build image and run playbook
.\run.ps1 -Shell   # open bash inside the container
.\run.ps1 -Stop    # remove container and volumes
```

Exposed ports (forwarded from the container to `localhost`):

| Port | Service |
|------|---------|
| 30080 | nginx — http://localhost:30080 |
| 30443 | ArgoCD UI — https://localhost:30443 |
| 6443 | k3s API server |

---

## Verify the deployment

```bash
# On the target machine (or inside the Docker container)
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
| `argocd_repo_url` | *(placeholder)* | Public git repo URL for ArgoCD to sync from |
| `argocd_namespace` | `argocd` | Namespace for ArgoCD components |
| `webapp_namespace` | `webapp` | Namespace for the nginx application |
