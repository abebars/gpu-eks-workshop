# 4. Preflight check

<div class="ws-meta" markdown>
<span>**Your time:** 1 min</span>
<span>**Do this:** the morning of the workshop, before we start</span>
</div>

One command. If it's green, you're ready.

```bash
cd gpu-eks-workshop
source .workshop.env
make preflight
```

<div class="ws-output" markdown>
```text
Tools
  ✅ aws: /opt/homebrew/bin/aws
  ✅ kubectl: /opt/homebrew/bin/kubectl
  ✅ helm: /opt/homebrew/bin/helm
  ✅ terraform: /opt/homebrew/bin/terraform
  ✅ jq: /opt/homebrew/bin/jq
  ✅ envsubst: /opt/homebrew/bin/envsubst
  ✅ git: /usr/bin/git
  ✅ curl: /usr/bin/curl
  ✅ aws CLI 2.28.4
  ✅ kubectl 1.36.0
  ✅ helm 3.19.0
  ✅ terraform 1.13.2

AWS credentials (us-east-1)
  ✅ account 123456789012 as arn:aws:iam::123456789012:user/ahmed

GPU quota (us-east-1)
    Running On-Demand G and VT instances            32 vCPUs  ✅
    All G and VT Spot Instance Requests             32 vCPUs  ✅

Base stack
  ✅ terraform output cluster_name=gpu-workshop
  ✅ kubectl reaches the cluster (2 nodes)
  ✅ karpenter/karpenter present
  ✅ monitoring/kube-prometheus-stack-operator present
  ✅ keda/keda-operator present

🚀 Preflight passed.
```
</div>

Anything with a ❌ links back to the relevant pre-work page. Two that come up often:

- **`kubectl cannot reach the cluster`** — your credentials rotated overnight. Re-authenticate (`aws sso login` or equivalent) and run `make kubeconfig`.
- **Quota still ❌** — the increase hasn't been approved. Try the other region if you have time; otherwise tell us at the start and we'll pair you up.

## On the day

Join 10 minutes early. While the "starting soon" slide is up:

1. Run `make preflight` one more time.
2. Open two terminal panes. You'll want one for commands and one for `kubectl get pods -w`-style watches.
3. Open the [Troubleshooting](../troubleshooting.md) page in a tab. It's organised by symptom.

See you in [Module 1 →](../01-why-gpus-are-hard/index.md)
