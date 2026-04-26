# BoilStream Helm Charts

Official Helm charts for deploying BoilStream on Kubernetes.

## Charts

- **[boilstream](./boilstream/)** — StatefulSet-based cluster with Envoy Gateway SNI routing, cert-manager TLS, and optional cluster-mode mTLS.

## Install via OCI

```bash
helm install boilstream oci://ghcr.io/boilingdata/charts/boilstream \
  --version 0.3.27 \
  -n boilstream --create-namespace \
  -f my-values.yaml
```

## Install from source

```bash
helm install boilstream ./charts/boilstream \
  -n boilstream --create-namespace \
  -f my-values.yaml
```

## Prerequisites

- [cert-manager](https://cert-manager.io) >= 1.13
- [Envoy Gateway](https://gateway.envoyproxy.io) >= 1.2

See [docs.boilstream.com/guide/kubernetes](https://docs.boilstream.com/guide/kubernetes.html) for the full deployment guide.

## Releasing

Chart releases are cut via the `publish-chart.yaml` workflow on `chart-v*` tags:

```bash
git tag chart-v0.3.0
git push --tags
```

The workflow lints, packages, and pushes the chart to `oci://ghcr.io/boilingdata/charts`.
