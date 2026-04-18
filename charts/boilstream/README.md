# BoilStream Helm chart

Deploys a BoilStream cluster on Kubernetes — StatefulSet of N pods sharing
state via S3 (cluster coordination + per-user catalog backups), with optional
Envoy Gateway SNI routing and pod-to-pod mTLS.

## Prerequisites

The chart **does not** install these — operators must provide them:

| Prereq | Why |
|---|---|
| **cert-manager ≥ 1.13** | Issues the public wildcard cert and (optionally) the internal cluster-mTLS cert. Skip if you supply both via `tls.existingSecret` and `clusterTls.existingSecret`. |
| **A `ClusterIssuer`** named in `tls.issuer.name` (default `boilstream-ca-issuer`) | cert-manager needs an issuer to mint certs. Self-signed CA, Let's Encrypt + DNS-01, or ACM Private CA all work. |
| **Envoy Gateway ≥ 1.2** with a `GatewayClass` named in `gateway.className` (default `eg`) | The chart-managed `Gateway` + `TLSRoute` resources reference this class. Skip by setting `gateway.enabled: false` (clients then must reach the Pods/headless Service directly). |
| **An S3-compatible bucket** at `s3.endpoint` (real S3, MinIO, RustFS, R2…) | Stores leader.json, broker registry, per-user catalog backups. |

Quick local install of the prereqs (tested on OrbStack k8s):

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.2.1 \
  -n envoy-gateway-system --create-namespace
helm install cert-manager jetstack/cert-manager --version v1.16.2 \
  -n cert-manager --create-namespace --set crds.enabled=true
kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: selfsigned-root }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: boilstream-ca, namespace: cert-manager }
spec:
  isCA: true
  commonName: BoilStream Local CA
  secretName: boilstream-ca-tls
  privateKey: { algorithm: ECDSA, size: 256 }
  issuerRef: { name: selfsigned-root, kind: ClusterIssuer }
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: boilstream-ca-issuer }
spec: { ca: { secretName: boilstream-ca-tls } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: eg }
spec: { controllerName: gateway.envoyproxy.io/gatewayclass-controller }
YAML
```

## Install

**Local dev (OrbStack + RustFS, defaults):**

```bash
helm install boilstream ./charts/boilstream
```

**EKS (AWS S3 + ACM/Let's Encrypt + Pod Identity):**

```bash
helm install boilstream ./charts/boilstream \
  -f ./charts/boilstream/values-eks-example.yaml \
  --set image.repository=<account>.dkr.ecr.<region>.amazonaws.com/boilstream \
  --set image.tag=0.10.0 \
  --set superadmin.existingSecret=boilstream-superadmin \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::...
```

## Key values

| Group | Key | Default | Notes |
|---|---|---|---|
| Replicas | `replicas` | `3` | Min 1, recommended ≥3 for quorum-style availability. |
| Image | `image.repository`, `image.tag`, `image.pullPolicy`, `image.pullSecrets` | `boilstream:local-1.5.2`, `Never`, `[]` | Set `pullSecrets: [{name: regcred}]` for private registries. |
| Naming | `namespace`, `namespaceCreate`, `nameOverride`, `fullnameOverride` | `boilstream`, `true` | Set `namespaceCreate: false` if using `--create-namespace` or pre-managed namespaces. |
| Public TLS | `tls.existingSecret`, `tls.issuer.{name,kind}` | (chart-managed) | Provide `existingSecret` to use ACM-imported or pre-issued certs. |
| Cluster mTLS | `clusterTls.enabled`, `clusterTls.issuer.*` | `false` | Pod-to-pod gRPC on `:8444`. Separate trust root from public edge. |
| Gateway | `gateway.enabled`, `gateway.className`, `gateway.serviceAnnotations` | `true`, `eg`, `{}` | Annotations propagate to the LB Service Envoy Gateway provisions. |
| ServiceAccount | `serviceAccount.{create,name,annotations}` | `true`, `boilstream`, `{}` | Set `eks.amazonaws.com/role-arn` for IRSA / Pod Identity. |
| Resources | `resources.requests`, `resources.limits` | dev-sized | **Override for production** — see EKS overlay. |
| Disruption | `podDisruptionBudget.{enabled,maxUnavailable\|minAvailable}` | `true`, `1` | Voluntary-disruption guard during drains/upgrades. |
| Lifecycle | `terminationGracePeriodSeconds`, `preStopSleepSeconds` | `120`, `5` | Time for in-flight S3 flush + leader stepdown. |
| S3 | `s3.{endpoint,bucket,region,prefix,forcePathStyle,accessKey,secretKey}` | RustFS dev defaults | Leave creds empty on EKS to use the IRSA role. |
| Superadmin | `superadmin.password` *or* `superadmin.existingSecret` | dev literal | **Always override in prod** — use `existingSecret` from sealed-secrets / ESO / SSM. |

See [`values.yaml`](values.yaml) for the full set with inline comments, and
[`values-eks-example.yaml`](values-eks-example.yaml) for a production-shaped
override.

## Architecture summary

- **StatefulSet** of `replicas` pods. Each pod has an emptyDir for hot-tier
  data (`./data/duckdb/`, `./data/tantivy/`); BoilStream uploads to S3
  continuously, so pod loss is recoverable.
- **Headless Service** gives every pod a stable per-pod DNS name
  `boilstream-N.boilstream-headless.<ns>.svc.cluster.local`. Used as
  `cluster_mode.advertised_host`.
- **Per-pod ClusterIP Services** are the backends for SNI-routed TLSRoutes.
- **Envoy Gateway** (when enabled) exposes one TLS-passthrough listener per
  protocol; SNI hostname `boilstream-N.<domain>` routes to the matching pod.
- **cert-manager** issues `*.<domain>` (public) and the cluster-mTLS cert.
- **S3** is the source of truth for cluster coordination
  (`<prefix>cluster_state/leader.json`, `<prefix>cluster_state/brokers/*.json`)
  and per-user catalog backups.

## Verify

After install:

```bash
kubectl -n <ns> rollout status statefulset/boilstream
kubectl -n <ns> get pods,gateway,certificate,secret
```

Production-readiness suite (from `tests/k8s/`):

```bash
cd tests/k8s
pip install -r requirements.txt
pytest -v -k "not destructive"
```

## Upgrade

```bash
helm upgrade boilstream ./charts/boilstream -f my-values.yaml
```

The StatefulSet selector is intentionally narrow (`app: boilstream`) to keep
upgrade-compatible across chart-version bumps. Standard `app.kubernetes.io/*`
labels are added on top for tooling.
