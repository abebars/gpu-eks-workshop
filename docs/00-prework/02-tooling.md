# 2. Install the tools

<div class="ws-meta" markdown>
<span>**Your time:** 10–15 min</span>
<span>**Do this:** any time this week</span>
</div>

Everything in the labs is `kubectl`, `helm`, `terraform` and the AWS CLI. The version floors matter: the cluster runs **Kubernetes 1.36**, and `kubectl` must be within one minor version of the server.

| Tool | Minimum | Why |
|------|---------|-----|
| `aws` CLI | 2.15 | `eks update-kubeconfig`, Service Quotas, SSM parameter lookups |
| `kubectl` | 1.35 | version skew policy: ±1 minor of the 1.36 control plane |
| `helm` | 3.14 | GPU Operator install |
| `terraform` | 1.5.7 | the `terraform-aws-modules/eks` v21 module requires it |
| `jq` | any | parsing outputs in scripts |
| `envsubst` | any | substituting `${CLUSTER_NAME}` into manifests (part of GNU gettext) |
| `git`, `curl` | any | |

Optional but nice: `watch` (not on macOS by default — `brew install watch`), [`k9s`](https://k9scli.io/) for watching pods and nodes, and [`kubectx`/`kubens`](https://github.com/ahmetb/kubectx).

=== "macOS (Homebrew)"

    ```bash
    brew install awscli kubernetes-cli helm terraform jq gettext git watch
    brew link --force gettext     # puts envsubst on your PATH
    ```

=== "Linux (Debian/Ubuntu)"

    ```bash
    sudo apt-get update && sudo apt-get install -y jq gettext-base git curl unzip
    # AWS CLI v2
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && unzip -q awscliv2.zip && sudo ./aws/install
    # kubectl (match the cluster's minor version)
    curl -sSLO "https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl" && sudo install -m 0755 kubectl /usr/local/bin/kubectl
    # helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    # terraform — follow https://developer.hashicorp.com/terraform/install for your distro
    ```

=== "Windows (WSL2)"

    Use the **Linux** instructions inside your WSL2 Ubuntu shell. Run everything from WSL, not PowerShell — the guide's commands assume a POSIX shell, and `envsubst`/`make` are expected to exist.

## Configure AWS credentials

Whatever you normally use is fine — `aws configure`, SSO (`aws sso login`), or exported keys. The check is:

```bash
aws sts get-caller-identity
```

<div class="ws-output" markdown>
```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/ahmed"
}
```
</div>

!!! warning "Session tokens expire"
    If you use SSO or STS credentials with a short lifetime, make sure you can refresh them mid-session. A credential that expires 90 minutes into a 3.5-hour workshop will fail exactly when Karpenter is launching your node.

## Verify

```bash
cd gpu-eks-workshop
make preflight
```

The **Tools** and **AWS credentials** sections should be all green. The **Base stack** section will warn that it isn't deployed yet — that's the next step.

[Next: deploy the base stack →](03-base-stack.md)
