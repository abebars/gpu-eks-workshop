# 1. Request GPU quota

<div class="ws-meta" markdown>
<span>**Your time:** 5 min</span>
<span>**AWS time:** minutes to 48 hours</span>
<span>**Do this:** today</span>
</div>

EC2 limits how many vCPUs of each instance *class* you can run. GPU instances are the **G and VT** class, and on a fresh account the limit is **zero** — for On-Demand *and* for Spot, separately. Nothing in this workshop works until both are raised.

## How much you need

The labs peak at **three GPU nodes** at once (one serving replica, one scaling replica, one "forgotten" pod you will hunt down in Module 5). Karpenter is allowed to pick from `g5.xlarge` (4 vCPUs), `g5.2xlarge` (8), `g6.xlarge` (4) and `g6.2xlarge` (8). Worst case that is 24 vCPUs, so:

| Quota | Code | Request |
|-------|------|---------|
| Running On-Demand G and VT instances | `L-DB2E81BA` | **32 vCPUs** |
| All G and VT Spot Instance Requests | `L-3819A6DF` | **32 vCPUs** |

Both. Karpenter tries Spot first and falls back to On-Demand; if either quota is zero, the fallback path is dead and you'll be staring at `Pending` pods.

## Check what you have

Clone the companion repo first (you'll need it for everything else anyway):

```bash
git clone https://github.com/abebars/gpu-eks-workshop.git
cd gpu-eks-workshop
export AWS_REGION=us-east-1   # or us-west-2
make check-quota
```

<div class="ws-output" markdown>
```text
  Running On-Demand G and VT instances             0 vCPUs  ❌ need 32
  All G and VT Spot Instance Requests              0 vCPUs  ❌ need 32

GPU quota is NOT sufficient in us-east-1.
Run: ./scripts/check-quota.sh --request   (or use the Service Quotas console).
```
</div>

## Request the increase

=== "CLI (fastest)"

    ```bash
    make request-quota
    ```

    <div class="ws-output" markdown>
    ```text
      Running On-Demand G and VT instances             0 vCPUs  ❌ need 32
         → requested: Running On-Demand G and VT instances   PENDING
      All G and VT Spot Instance Requests              0 vCPUs  ❌ need 32
         → requested: All G and VT Spot Instance Requests    PENDING
    ```
    </div>

=== "Console"

    1. Open **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** in the region you chose.
    2. Search for `G and VT`. You'll see both quotas.
    3. Select **Running On-Demand G and VT instances → Request increase at account level**, enter `32`, submit.
    4. Repeat for **All G and VT Spot Instance Requests**.

Small increases are often auto-approved within minutes; anything that goes to a human can take a day or two. You'll get an email either way. Re-run `make check-quota` until both lines are green.

!!! warning "If the request is denied or stuck"
    - Try the other region (`us-west-2`) — quotas are per region and approvals are independent.
    - A brand-new account with no billing history is the most common reason for a denial. Reply to the support case explaining it's for a training workshop with a bounded spend; that usually unblocks it.
    - Worst case, you can still attend and follow along on the shared screen, but you won't be able to run the labs. Tell us in advance so we can pair you with someone.

!!! quirk "Why vCPUs and not GPUs?"
    EC2 quotas are counted in vCPUs of the instance class, not in GPUs. A `g5.xlarge` and a `g5.12xlarge` both have "a GPU" (one and four, respectively) but cost 4 and 48 vCPUs of quota. When someone tells you "we have quota for GPUs", ask *how many vCPUs, which class, which region, Spot or On-Demand*.

[Next: install the tools →](02-tooling.md)
