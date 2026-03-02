# k3s + ArgoCD — single-node cluster bootstrap

Ansible-based automation that sets up a production-like Kubernetes environment on a single Linux machine:

- **k3s** single-node cluster
- **ArgoCD** for GitOps-style continuous deployment
- **nginx** as a sample web application exposed via NodePort
- **sysctl** network tunables applied automatically

---

## How it works

```
GitHub repo (manifests/)
       │
       │  ArgoCD auto-sync (on every git push)
       ▼
  k3s cluster
  └── webapp namespace
       └── nginx Deployment (2 replicas)
            └── Service NodePort :30080
```

ArgoCD continuously watches the `manifests/` directory in this repository.
Every `git push` automatically triggers a sync to the cluster — no manual `kubectl apply` needed.

---

## Repository structure

```
.
├── ansible/
│   ├── site.yml              # main playbook — installs k3s + ArgoCD
│   ├── requirements.yml      # Ansible Galaxy collections (sysctl, modprobe)
│   └── hosts.ini.example     # inventory template (copy to hosts.ini)
├── manifests/                # Kubernetes manifests — synced by ArgoCD
│   ├── namespace.yaml
│   ├── deployment.yaml       # nginx, 2 replicas
│   └── service.yaml          # NodePort 30080
├── argocd/
│   └── application.yaml      # ArgoCD Application resource
└── docker/                   # Windows dev helper — simulates a Linux VM
    ├── Dockerfile
    ├── docker-compose.yml
    ├── hosts.ini             # Ansible inventory for use inside the container
    └── run.ps1               # PowerShell launcher script
```

---

## Choosing your setup path

There are two ways to run this project. Choose based on your environment:

```
┌─────────────────────────────────────────────────────────┐
│  Option A — Linux (direct)                              │
│                                                         │
│  Your machine (Linux/Mac) = Ansible control node        │
│  Target = local machine or remote server via SSH        │
│                                                         │
│  You install Ansible locally and run the playbook.      │
│  → follow: Quick start (Linux)                          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Option B — Windows (Docker)                            │
│                                                         │
│  Windows                                                │
│  └── Docker container (Ubuntu image)                    │
│       ├── Ansible  ← pre-installed in the image         │
│       ├── kubectl  ← pre-installed in the image         │
│       └── k3s + ArgoCD ← installed by the playbook      │
│                                                         │
│  Docker acts as the Linux VM. No Ansible needed         │
│  on Windows itself.                                     │
│  → follow: Quick start (Windows)                        │
└─────────────────────────────────────────────────────────┘
```

---

## Quick start (Linux)

> Use this if you are running on Linux or macOS and want to target a local or remote machine.

### 1. Clone the repository

```bash
git clone https://github.com/JackN5y/k3s_ansible_demo.git
cd k3s_ansible_demo
```

### 2. Install Ansible and required collections

```bash
pip3 install ansible
ansible-galaxy collection install -r ansible/requirements.yml
```

> `requirements.yml` installs the `ansible.posix` and `community.general` collections
> used by the `sysctl` and `modprobe` tasks in the playbook.

### 3. Configure inventory

```bash
cp ansible/hosts.ini.example ansible/hosts.ini
```

Edit `hosts.ini` based on your target:

```ini
# Target = this machine (localhost)
[k3s_servers]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3

# Target = remote server via SSH
# [k3s_servers]
# 192.168.1.10 ansible_user=ubuntu ansible_become=true ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 4. Run the playbook

```bash
ansible-playbook -i ansible/hosts.ini ansible/site.yml
```

At the end of the run, the playbook prints:

```
ArgoCD URL  : https://<node-ip>:30443
Username    : admin
Password    : <generated>
nginx app   : http://<node-ip>:30080
```

---

## Quick start (Windows)

> Use this if you are on Windows. Docker acts as the Linux VM — no Ansible installation needed.

**Requirement:** Docker Desktop with Linux containers / WSL2 backend.

```powershell
git clone https://github.com/JackN5y/k3s_ansible_demo.git
cd k3s_ansible_demo\docker

Set-ExecutionPolicy -Scope Process RemoteSigned

.\run.ps1           # build image, run playbook, tail logs
.\run.ps1 -Rebuild  # force rebuild of the Docker image
.\run.ps1 -Shell    # open bash shell inside the running container
.\run.ps1 -Stop     # stop and remove the container + volume
```

Docker forwards these ports to `localhost` on Windows:

| Port | Service |
|------|---------|
| `30080` | nginx — http://localhost:30080 |
| `30443` | ArgoCD UI — https://localhost:30443 |
| `6443` | k3s API server |

> Ansible collections (`requirements.yml`) are installed automatically during `docker build`.
> You do not need Ansible on Windows.

---

## What the playbook does

| Tag | Step | Details |
|-----|------|---------|
| `sysctl` | Network tunables | `ip_forward=1`, `br_netfilter=1`, `somaxconn=65535`, `netdev_max_backlog=5000`, `ip_local_port_range=1024-65535`, `tcp_keepalive_time=300`, `tcp_max_syn_backlog=8192` |
| `k3s` | Install k3s | Official install script, version pinned, Traefik disabled, systemd service enabled |
| `argocd` | Install ArgoCD | Official `install.yaml` manifest, argocd-server exposed as NodePort 30443, argocd CLI installed |
| `argocd_app` | Apply Application | Applies `argocd/application.yaml`; ArgoCD begins auto-syncing `manifests/` from GitHub |

Run individual steps using tags:

```bash
ansible-playbook -i ansible/hosts.ini ansible/site.yml --tags sysctl
ansible-playbook -i ansible/hosts.ini ansible/site.yml --tags k3s,argocd
```

---

## ArgoCD Application

[argocd/application.yaml](argocd/application.yaml) configures ArgoCD to:

- Watch the `manifests/` directory in this repository (`https://github.com/JackN5y/k3s_ansible_demo.git`)
- Auto-sync on every commit (`automated.selfHeal: true`)
- Remove resources deleted from git (`prune: true`)
- Retry failed syncs up to 5 times with exponential backoff

---

## Verify the deployment

```bash
# on the Linux machine, or inside the Docker container (.\run.ps1 -Shell on Windows)
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
