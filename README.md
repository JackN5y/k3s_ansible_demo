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

## Kubeconfig setup (kubectl from Windows host)

After the cluster is running, copy the kubeconfig from the container and point kubectl at it:

```powershell
# 1. Copy kubeconfig from the container (re-run after every restart)
docker cp k3s-argocd-node:/etc/rancher/k3s/k3s.yaml "$env:USERPROFILE\.kube\k3s.yaml"

# 2. Set KUBECONFIG for the current PowerShell session
$env:KUBECONFIG = "$env:USERPROFILE\.kube\k3s.yaml"

# 3. Verify
kubectl get nodes
```

To persist `KUBECONFIG` permanently across all PowerShell sessions:

```powershell
[System.Environment]::SetEnvironmentVariable(
  "KUBECONFIG",
  "$env:USERPROFILE\.kube\k3s.yaml",
  "User"
)
```

> **Note:** Always re-copy the kubeconfig after `docker compose stop` / `docker compose start`
> because the container IP may change. After `docker compose down -v` (full reset) the
> cluster is wiped — rebuild with `docker compose up --build`.
>
> If you get a TLS certificate error, add `--insecure-skip-tls-verify` temporarily,
> or do a full reset with `docker compose down -v && docker compose up --build`.

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

## ArgoCD credentials

**Username:** `admin`

**Password** is auto-generated on first install and stored in a Kubernetes secret. Retrieve it with:

```powershell
# From your Windows host (PowerShell)
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Or from inside the container (base64 is available in bash)
docker exec k3s-argocd-node bash -c `
  "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

> After first login it is recommended to change the password via **User Info → Update Password** in the ArgoCD UI, or with:
> ```bash
> argocd account update-password
> ```

---

## Verify the deployment

### 1. Running the playbook

```bash
cd k3s_ansible_demo/docker
docker compose up --build
```

Watch the logs — bootstrap is complete when you see:

```
PLAY RECAP *********************************************************************
localhost : ok=XX  changed=XX  unreachable=0  failed=0
=== Bootstrap complete. Sentinel written to /var/lib/rancher/k3s/.bootstrap-complete ===
```

The entire first-run bootstrap (k3s + ArgoCD + nginx) takes **5–10 minutes** depending on download speed.
On subsequent starts (`docker compose stop` / `docker compose start`) it skips the playbook and starts in **~4–6 minutes**.

To follow logs after detaching:

```bash
docker compose logs -f
```

---

### 2. Cluster state

Run from **inside the container** or from the **Windows host** after [kubeconfig setup](#kubeconfig-setup-kubectl-from-windows-host).

```bash
# Node status — should show Ready
kubectl get nodes

# All pods — all should be Running (0 restarts expected)
kubectl get pods -A

# webapp service — confirms NodePort 30080 is assigned
kubectl get svc -n webapp
```

**Expected healthy output:**

```
NAME       STATUS   ROLES                  AGE   VERSION
k3s-node   Ready    control-plane,master   5m    v1.29.3+k3s1

NAMESPACE     NAME                                      READY   STATUS    RESTARTS
argocd        argocd-application-controller-0            1/1     Running   0
argocd        argocd-applicationset-controller-...       1/1     Running   0
argocd        argocd-dex-server-...                      1/1     Running   0
argocd        argocd-notifications-controller-...        1/1     Running   0
argocd        argocd-redis-...                           1/1     Running   0
argocd        argocd-repo-server-...                     1/1     Running   0
argocd        argocd-server-...                          1/1     Running   0
kube-system   coredns-...                                1/1     Running   0
kube-system   local-path-provisioner-...                 1/1     Running   0
kube-system   metrics-server-...                         1/1     Running   0
webapp        nginx-...                                  1/1     Running   0
webapp        nginx-...                                  1/1     Running   0

NAME      TYPE       CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
nginx-svc NodePort   10.43.x.x    <none>        80:30080/TCP   4m
```

> The node shows `NotReady` for the first ~5 minutes after start — this is normal while Flannel networking initialises.

---

### 3. ArgoCD verification

Check that the ArgoCD Application is **Synced** and **Healthy**:

```bash
# Summary — Status should be: Synced / Healthy
kubectl get application webapp -n argocd

# Full detail — shows sync revision, last sync time, and any errors
kubectl describe application webapp -n argocd
```

**Expected output:**

```
NAME     SYNC STATUS   HEALTH STATUS
webapp   Synced        Healthy
```

**From inside the container using the ArgoCD CLI:**

```bash
docker exec -it k3s-argocd-node bash

# Log in (get password first — see ArgoCD credentials section)
argocd login localhost:30443 --username admin --password <PASSWORD> --insecure

# Application status
argocd app get webapp

# Trigger a manual sync (optional)
argocd app sync webapp
```

**ArgoCD UI:** open https://localhost:30443 in your browser (accept the self-signed certificate).
Log in as `admin` with the password retrieved from the secret.
The `webapp` application should appear as **Synced ✓ Healthy ✓**.

---

### 4. Application availability

Confirm the nginx app responds on port 30080:

```bash
# From Windows host (PowerShell)
curl http://localhost:30080

# Or simply open in a browser
start http://localhost:30080
```

**Expected response:** HTTP 200 with the default nginx welcome page:

```html
<!DOCTYPE html>
<html>
<head><title>Welcome to nginx!</title></head>
...
```

From **inside the container:**

```bash
docker exec k3s-argocd-node curl -s -o /dev/null -w "%{http_code}" http://localhost:30080
# Expected: 200
```

**End-to-end GitOps test** — verify ArgoCD auto-sync is working:

```bash
# 1. Edit gitops/manifests/deployment.yaml and change replicas: 2 → 3
# 2. git commit -am "scale nginx to 3" && git push
# 3. Within ~3 minutes ArgoCD auto-syncs; verify:
kubectl get pods -n webapp
# Expected: 3 nginx pods Running
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
