# sre-gitops

GitOps source for the SRE agent demo on minikube. ArgoCD (app-of-apps) installs everything
in `apps/`; the SRE agent's fix PRs only touch `charts/apps/{pulsar,voyager}/`.

```
bootstrap/            argocd-values.yaml (helm install once), root.yaml (app-of-apps)
apps/                 one ArgoCD Application per component
charts/infra/         grafana, loki, prometheus(+alertmanager), fluent-bit, mcp-grafana, kubernetes-mcp, sre-agent
charts/apps/          pulsar, voyager, loadgen   <- fix PRs land here
```

| Component | Namespace | In-cluster endpoint |
|---|---|---|
| Grafana | o11y | `grafana.o11y:80` |
| Loki (SingleBinary, ruler on) | o11y | `loki.o11y:3100` |
| Prometheus / Alertmanager | o11y | `prometheus-server.o11y:80` / `prometheus-alertmanager.o11y:9093` |
| Grafana MCP (read-only) | o11y | `http://mcp-grafana.o11y:8000/mcp` |
| Kubernetes MCP (read-only) | o11y | `http://mcp-kubernetes.o11y:8080/mcp` |
| Agent Server API / Chat UI | sre-agent | `sre-agent-api-server.sre-agent:80` / `sre-agent-chat-ui:3000` |
| pulsar / voyager / loadgen | default | `pulsar.default:5001` / `voyager.default:5050` |

## Bootstrap (once)

```sh
K="--context=minikube"
helm install argocd argo/argo-cd --version 10.18.3 -n argocd --create-namespace \
  --kube-context=minikube -f bootstrap/argocd-values.yaml

# The repo is public, so ArgoCD reads it over HTTPS with no credentials.
# If it is ever made private, add a read-only repo secret in ns argocd first.
kubectl $K apply -f bootstrap/root.yaml
```

## Secrets (created by hand, never committed)

| Secret | Namespace | Keys | Notes |
|---|---|---|---|
| `grafana-admin` | o11y | `admin-user`, `admin-password` | create **before** Grafana first starts (Grafana reads it only when its DB is created) |
| `mcp-grafana-token` | o11y | `GRAFANA_SERVICE_ACCOUNT_TOKEN` | Grafana service account with role **Viewer**, created after Grafana is up |
| `sre-agent-secrets` | sre-agent | `api_key` (LangSmith), `OPENROUTER_API_KEY`, `GITHUB_PAT` | see the sre-agent repo README; the PAT is fine-grained, this repo only, Contents RW + Pull requests RW |

```sh
kubectl $K create ns o11y
kubectl $K -n o11y create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-literal=admin-password="$(openssl rand -base64 18)"
```

## Grafana token for mcp-grafana (after Grafana is up)

```sh
kubectl $K -n o11y port-forward svc/grafana 3000:80 &
PW=$(kubectl $K -n o11y get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)
SA=$(curl -s -u admin:$PW -H 'Content-Type: application/json' localhost:3000/api/serviceaccounts \
     -d '{"name":"mcp-grafana","role":"Viewer"}' | jq .id)
TOKEN=$(curl -s -u admin:$PW -H 'Content-Type: application/json' localhost:3000/api/serviceaccounts/$SA/tokens \
     -d '{"name":"mcp-grafana"}' | jq -r .key)
kubectl $K -n o11y create secret generic mcp-grafana-token --from-literal=GRAFANA_SERVICE_ACCOUNT_TOKEN=$TOKEN
```

## UIs

```sh
kubectl --context=minikube -n argocd port-forward svc/argocd-server 8080:80   # admin / argocd-initial-admin-secret
kubectl --context=minikube -n o11y port-forward svc/grafana 3000:80
```

## Demo scenarios (each is one commit to main)

| # | Change | Alert | Expected fix PR |
|---|---|---|---|
| 1 | `charts/apps/pulsar/values.yaml` `faultInjection.failEvery: 3` | `AppErrorLogs` (Loki) | `failEvery: 0` |
| 2 | pulsar `resources.limits.memory: 16Mi` | `ContainerOOMKilled` / `PodCrashLooping` | back to `128Mi` |
| 3 | voyager `image.tag: v0.0.2` | `PodWaitingBadState` | back to `latest` |
