# IoT Bonus - Local GitLab with K3d and Argo CD

This bonus keeps your Part 3 logic, but replaces GitHub with a local GitLab instance.

## What it creates

- K3d cluster: `mycluster`
- Kubernetes namespaces: `argocd`, `dev`, `gitlab`
- Local GitLab CE Docker container
- A Kubernetes `ExternalName` service in the `gitlab` namespace pointing to local GitLab
- Local GitLab project: `root/bel-idri`
- Argo CD Application reading from the local GitLab repository
- Application in `dev` using `wil42/playground:v1`
- Ingress URL for the app: `http://app.127.0.0.1.nip.io`

## Run

```bash
chmod +x bonus/scripts/*.sh
sudo bash bonus/scripts/setup_bonus.sh
```

## Test

```bash
bash bonus/scripts/test_bonus.sh
curl http://app.127.0.0.1.nip.io
```

## Change from v1 to v2

```bash
bash bonus/scripts/update_to_v2.sh
```

Then check:

```bash
curl http://app.127.0.0.1.nip.io
kubectl get pods -n dev
kubectl get application -n argocd my-app
```

## Argo CD UI

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Open:

```text
https://localhost:8080
```

Username: `admin`

The password is printed at the end of `setup_bonus.sh`.

## GitLab UI

Open:

```text
http://gitlab.gitlab.svc.cluster.local:8929
```

Username: `root`

Password: `RootPassword42!`
