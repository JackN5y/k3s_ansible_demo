# run.ps1 — Build and launch the k3s-argocd demo environment via Docker.
# Requires: Docker Desktop (Linux containers / WSL2 backend).
#
# Usage:
#   .\run.ps1               # build image (if needed) and start, then tail logs
#   .\run.ps1 -Rebuild      # force rebuild of the Docker image
#   .\run.ps1 -Shell        # open a bash shell in the running container
#   .\run.ps1 -Stop         # stop and remove container + named volume

param(
    [switch]$Rebuild,
    [switch]$Shell,
    [switch]$Stop
)

$ErrorActionPreference = "Stop"
$ComposeFile = Join-Path $PSScriptRoot "docker-compose.yml"

function Test-Docker {
    try { docker info 2>$null | Out-Null; return $true } catch { return $false }
}

if (-not (Test-Docker)) {
    Write-Error "Docker is not running. Start Docker Desktop and try again."
    exit 1
}

if ($Stop) {
    Write-Host "Stopping containers and removing volumes..." -ForegroundColor Yellow
    docker compose -f $ComposeFile down -v --remove-orphans
    Write-Host "Done." -ForegroundColor Green
    exit 0
}

if ($Shell) {
    docker exec -it k3s-argocd-node bash
    exit 0
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  k3s + ArgoCD demo — Docker launcher (Windows) " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  nginx  : http://localhost:30080"
Write-Host "  ArgoCD : https://localhost:30443  (user: admin)"
Write-Host ""
Write-Host "NOTE: First run downloads k3s + ArgoCD (~400 MB). Be patient." -ForegroundColor Yellow
Write-Host ""

if ($Rebuild) {
    docker compose -f $ComposeFile up -d --build
} else {
    docker compose -f $ComposeFile up -d
}

if ($LASTEXITCODE -ne 0) { Write-Error "docker compose failed."; exit 1 }

Write-Host ""
Write-Host "Container started. Streaming playbook output (Ctrl+C to stop tailing):" -ForegroundColor Green
docker logs -f k3s-argocd-node
