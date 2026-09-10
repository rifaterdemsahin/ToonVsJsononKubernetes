# Deployment log

What this repo contains and every step taken to get the TOON vs JSON demo
running on Kubernetes, both locally and in GitHub Codespaces.

## What's in the repo

| Path | Purpose |
|---|---|
| `site/index.html` | Self-contained comparison page: renders the same sample data as JSON and TOON, estimates token/char savings, explains why TOON is cheaper for LLM payloads. |
| `site/nginx.conf` | Custom nginx server block with larger header/cookie buffers (fixes `400 Request Header Or Cookie Too Large` seen on `localhost`). |
| `Dockerfile` | `nginx:alpine` serving `site/` with the custom `nginx.conf`. |
| `k8s/deployment.yaml` | 2-replica Deployment, `imagePullPolicy: Never` (image is built directly into the cluster's Docker daemon, no registry needed). |
| `k8s/service.yaml` | `NodePort` Service (`nodePort: 30080`) exposing the deployment. |
| `.devcontainer/devcontainer.json` | Codespaces devcontainer: docker-in-docker + kubectl/helm/minikube features, forwards port 8080, runs the deploy script on container create. |
| `scripts/codespaces-deploy.sh` | Automates `minikube start` → build → `kubectl apply` → port-forward, for both Codespaces and manual local re-runs. |

## Steps completed locally (macOS)

1. Confirmed `minikube`, `kubectl`, `docker` were installed; Docker Desktop wasn't running, so it was launched with `open -a Docker` and polled until `docker info` succeeded.
2. Authored `site/index.html`, `Dockerfile`, `k8s/deployment.yaml`, `k8s/service.yaml`.
3. `minikube start --driver=docker`.
4. `eval $(minikube docker-env)` then `docker build -t toon-vs-json:latest .` — this builds the image directly inside minikube's own Docker daemon, so the cluster can use it with `imagePullPolicy: Never` and no image registry/push step.
5. `kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml`, then `kubectl rollout status deployment/toon-vs-json` to confirm both replicas came up.
6. Exposed it with `kubectl port-forward svc/toon-vs-json 8080:80` and opened `http://localhost:8080` in Google Chrome (per user's global Chrome preference).
7. Hit `400 Bad Request — Request Header Or Cookie Too Large` from nginx, caused by accumulated cookies Chrome holds for the `localhost` hostname (shared across all ports/apps). Fixed by adding `site/nginx.conf` with `large_client_header_buffers 4 32k;` and `client_header_buffer_size 16k;`, wiring it into the `Dockerfile`, rebuilding the image in minikube's Docker daemon, and `kubectl rollout restart deployment/toon-vs-json`. Verified with `curl` sending a synthetic 9 KB cookie — still `200 OK`.
8. Committed and pushed both the initial deployment and the nginx fix to `origin/main`.

## Running it in GitHub Codespaces

Codespaces runs the devcontainer as root inside a container, so minikube needs
`--force` to start with the `docker` driver there — everything else is the
same pipeline as the local run above, just automated.

1. Open this repo in a Codespace (or `Code` → `Create codespace on main` on GitHub, or `gh codespace create -r <owner>/ToonVsJsononKubernetes`).
2. The devcontainer builds with the `docker-in-docker` and `kubectl-helm-minikube` features, then `postCreateCommand` runs `scripts/codespaces-deploy.sh` automatically:
   - `minikube start --driver=docker --force`
   - builds `toon-vs-json:latest` inside minikube's Docker daemon
   - `kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml`
   - `kubectl rollout status deployment/toon-vs-json`
   - backgrounds `kubectl port-forward --address 0.0.0.0 svc/toon-vs-json 8080:80`
3. Codespaces detects the forwarded port 8080 (declared in `devcontainer.json` `forwardPorts`) and opens it automatically (`onAutoForward: openBrowser`); otherwise open it manually from the **Ports** tab.
4. To re-run after the container is already up (e.g. after editing `site/index.html`): `bash scripts/codespaces-deploy.sh`.
5. To share the URL outside your own GitHub session: `gh codespace ports visibility 8080:public -c $CODESPACE_NAME`.
