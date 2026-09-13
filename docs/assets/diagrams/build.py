#!/usr/bin/env python3
"""Regenerates every diagram under docs/assets/diagrams.

    pip install diagrams pillow   # plus graphviz on the host
    python3 docs/assets/diagrams/build.py

Architecture diagrams use the `diagrams` library (AWS / Kubernetes icons).
Conceptual diagrams are hand-built SVG so they stay crisp at any size.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent

# ---------------------------------------------------------------- palette
INK = "#1f2937"
MUTED = "#6b7280"
LINE = "#9ca3af"
GREEN = "#059669"
GREEN_BG = "#ecfdf5"
AMBER = "#d97706"
AMBER_BG = "#fffbeb"
RED = "#dc2626"
RED_BG = "#fef2f2"
BLUE = "#2563eb"
BLUE_BG = "#eff6ff"
GRAY_BG = "#f3f4f6"
WHITE = "#ffffff"


# ---------------------------------------------------------------- gpu icon
def gpu_icon(path: Path, size=256):
    """An original, generic GPU-card glyph for the diagrams library."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = size * 0.08
    d.rounded_rectangle([m, size * 0.22, size - m, size * 0.78], radius=size * 0.06, fill="#111827", outline="#4b5563", width=4)
    # die
    d.rounded_rectangle([size * 0.30, size * 0.34, size * 0.70, size * 0.66], radius=size * 0.03, fill="#76b900")
    # pins
    for i in range(10):
        x = m + size * 0.05 + i * (size - 2 * m - size * 0.10) / 9
        d.rectangle([x - 4, size * 0.78, x + 4, size * 0.86], fill="#9ca3af")
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(size * 0.13))
    except OSError:
        font = ImageFont.load_default()
    d.text((size / 2, size * 0.50), "GPU", fill="#ffffff", anchor="mm", font=font)
    img.save(path)


# ---------------------------------------------------------------- svg helpers
class SVG:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif" font-size="14">',
            '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">'
            f'<path d="M 0 0 L 10 5 L 0 10 z" fill="{LINE}"/></marker></defs>',
            f'<rect width="{w}" height="{h}" fill="{WHITE}"/>',
        ]

    def box(self, x, y, w, h, fill=GRAY_BG, stroke=LINE, r=8, dash=None, sw=1.5):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def text(self, x, y, s, size=14, fill=INK, weight="normal", anchor="middle", family=None):
        s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        f = f' font-family="{family}"' if family else ""
        self.parts.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" font-weight="{weight}" text-anchor="{anchor}"{f}>{s}</text>')

    def lines(self, x, y, items, size=13, fill=INK, anchor="middle", lh=18, weight="normal", family=None):
        for i, s in enumerate(items):
            self.text(x, y + i * lh, s, size=size, fill=fill, anchor=anchor, weight=weight, family=family)

    def arrow(self, x1, y1, x2, y2, stroke=LINE, dash=None, sw=1.8):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}" marker-end="url(#arrow)"{d}/>')

    def line(self, x1, y1, x2, y2, stroke=LINE, dash=None, sw=1.5):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def pill(self, x, y, s, fill=GREEN_BG, stroke=GREEN, color=GREEN, size=12):
        w = len(s) * size * 0.62 + 18
        self.parts.append(f'<rect x="{x - w/2}" y="{y - 11}" width="{w}" height="22" rx="11" fill="{fill}" stroke="{stroke}"/>')
        self.text(x, y + 4, s, size=size, fill=color, weight="600")

    def save(self, path: Path):
        self.parts.append("</svg>")
        path.write_text("\n".join(self.parts))


# ---------------------------------------------------------------- 1. GPU software stack
def gpu_stack():
    s = SVG(980, 560)
    s.text(490, 34, "The GPU stack on Kubernetes, bottom-up: who provides each layer on EKS", size=18, weight="700")
    layers = [
        ("Your Pod", "resources.limits: nvidia.com/gpu: 1", "You", BLUE_BG, BLUE),
        ("kube-scheduler", "places the pod on a node whose allocatable nvidia.com/gpu ≥ 1", "Kubernetes", GRAY_BG, MUTED),
        ("kubelet extended resource", "nvidia.com/gpu advertised in node capacity / allocatable (integers only)", "Device plugin registers it", GRAY_BG, MUTED),
        ("NVIDIA device plugin (+ GFD, DCGM exporter)", "discovers GPUs, mounts /dev/nvidia*, labels the node, exports metrics", "NVIDIA GPU Operator  ← you install this", GREEN_BG, GREEN),
        ("NVIDIA Container Toolkit", "containerd runtime hook that injects the GPU into the container", "EKS AL2023 NVIDIA AMI (pre-installed)", AMBER_BG, AMBER),
        ("NVIDIA kernel driver + CUDA user-mode driver", "kernel module talking to the PCIe device; must match the CUDA version your image expects", "EKS AL2023 NVIDIA AMI (pre-installed)", AMBER_BG, AMBER),
        ("GPU hardware", "A10G (g5) · L4 (g6) · L40S (g6e) · H100 (p5)", "EC2 via Karpenter", GRAY_BG, MUTED),
    ]
    x, y, w, h, gap = 40, 70, 600, 58, 8
    for i, (title, sub, who, bg, col) in enumerate(layers):
        yy = y + i * (h + gap)
        s.box(x, yy, w, h, fill=bg, stroke=col)
        s.text(x + 16, yy + 24, title, size=15, weight="700", anchor="start")
        s.text(x + 16, yy + 44, sub, size=12, fill=MUTED, anchor="start")
        s.box(x + w + 20, yy + 10, 290, 38, fill=WHITE, stroke=col, r=19)
        s.text(x + w + 20 + 145, yy + 34, who, size=12.5, fill=col, weight="600")
    # arrows up the stack
    for i in range(len(layers) - 1):
        yy = y + i * (h + gap)
        s.arrow(x - 14, yy + h + gap + h / 2, x - 14, yy + h / 2 + 4, stroke=LINE)
    s.text(20, 300, "a request flows up", size=11, fill=MUTED, anchor="middle")
    s.parts[-1] = s.parts[-1].replace('<text ', '<text transform="rotate(-90 20 300)" ')
    s.text(490, 540, "Rule of thumb: the AMI owns everything below the container boundary; the Operator owns everything Kubernetes sees.", size=13, fill=MUTED)
    s.save(HERE / "gpu-stack.svg")


# ---------------------------------------------------------------- 2. sharing options
def sharing_options():
    s = SVG(1040, 520)
    s.text(520, 34, "Four ways to hand a GPU to pods", size=18, weight="700")
    cols = [
        ("Exclusive", "1 pod : 1 GPU", ["Full isolation", "Predictable latency", "Idle capacity = waste", "Any GPU"], GRAY_BG, MUTED, "Default. Latency-critical serving.", 1),
        ("Time-slicing", "N pods : 1 GPU, round-robin", ["No memory isolation", "No fault isolation", "Context-switch overhead → p99", "Any GPU (A10G/L4 OK)"], AMBER_BG, AMBER, "Dev/test, bursty low-priority inference. Lab today.", 4),
        ("MIG", "Up to 7 hardware slices", ["Memory + fault isolation", "Guaranteed SM/bandwidth share", "Fixed profiles (1g.10gb…)", "A100 / H100 / H200 / B200 only"], GREEN_BG, GREEN, "Multi-tenant SLO-bound serving. Slides only (g5/g6 can't).", 7),
        ("MPS", "CUDA-level concurrency", ["Shared address space", "Lower overhead than slicing", "Experimental in device plugin", "Any GPU"], BLUE_BG, BLUE, "Many small kernels from trusted clients.", 3),
    ]
    x0, y0, w, h = 30, 70, 240, 400
    for i, (name, tag, bullets, bg, col, use, parts) in enumerate(cols):
        x = x0 + i * (w + 15)
        s.box(x, y0, w, h, fill=WHITE, stroke=col, sw=2)
        s.text(x + w / 2, y0 + 30, name, size=17, weight="700", fill=col)
        s.text(x + w / 2, y0 + 50, tag, size=12, fill=MUTED)
        # GPU glyph with partitions
        gx, gy, gw, gh = x + 30, y0 + 70, w - 60, 90
        s.box(gx, gy, gw, gh, fill="#111827", stroke="#4b5563", r=6)
        if parts == 1:
            s.box(gx + 8, gy + 8, gw - 16, gh - 16, fill="#76b900", stroke="#76b900", r=4)
            s.text(gx + gw / 2, gy + gh / 2 + 5, "pod A", size=12, fill=WHITE, weight="600")
        elif parts == 4:
            pw = (gw - 16) / 4
            for k in range(4):
                s.box(gx + 8 + k * pw + 2, gy + 8, pw - 4, gh - 16, fill="#76b900", stroke="#a3e635", r=3, dash="3,2")
                s.text(gx + 8 + k * pw + pw / 2, gy + gh / 2 + 4, "t", size=11, fill=WHITE)
            s.text(gx + gw / 2, gy + gh + 16, "same memory, shared in time", size=11, fill=MUTED)
        elif parts == 7:
            pw = (gw - 16) / 7
            for k in range(7):
                s.box(gx + 8 + k * pw + 1, gy + 8, pw - 2, gh - 16, fill="#76b900", stroke="#111827", r=2, sw=2)
            s.text(gx + gw / 2, gy + gh + 16, "hardware-partitioned memory + SMs", size=11, fill=MUTED)
        else:
            s.box(gx + 8, gy + 8, gw - 16, gh - 16, fill="#76b900", stroke="#76b900", r=4)
            for k in range(3):
                s.text(gx + 30 + k * 60, gy + gh / 2 + 5, f"k{k+1}", size=12, fill=WHITE, weight="600")
            s.text(gx + gw / 2, gy + gh + 16, "kernels interleave on one context", size=11, fill=MUTED)
        for j, b in enumerate(bullets):
            s.text(x + 18, y0 + 210 + j * 22, "• " + b, size=12.5, anchor="start")
        s.box(x + 12, y0 + h - 78, w - 24, 62, fill=bg, stroke=col, r=6)
        words, line, ls = use.split(), "", []
        for wd in words:
            if len(line + " " + wd) > 30:
                ls.append(line.strip()); line = wd
            else:
                line += " " + wd
        ls.append(line.strip())
        s.lines(x + w / 2, y0 + h - 56, ls[:3], size=11.5, fill=col, lh=16, weight="600")
    s.save(HERE / "sharing-options.svg")


# ---------------------------------------------------------------- 3. cold start timeline
def cold_start():
    s = SVG(1200, 440)
    s.text(600, 34, "Anatomy of a GPU cold start (new replica, no warm node)", size=18, weight="700")
    phases = [
        ("Pod Pending → Karpenter decides", 0, 15, GRAY_BG, MUTED, "seconds"),
        ("EC2 launch, AL2023 NVIDIA AMI boot, node joins", 15, 150, AMBER_BG, AMBER, "2–3 min"),
        ("GPU Operator DaemonSets start, nvidia.com/gpu registers", 150, 190, GRAY_BG, MUTED, "30–60 s"),
        ("Pull vllm/vllm-openai image (~9 GB compressed)", 190, 400, RED_BG, RED, "3–5 min, EBS-throughput bound"),
        ("Download model weights (3 GB from Hugging Face)", 400, 470, AMBER_BG, AMBER, "~1 min"),
        ("vLLM init: weights → GPU, torch.compile, CUDA graphs", 470, 560, BLUE_BG, BLUE, "1–2 min"),
        ("Ready — first request served", 560, 572, GREEN_BG, GREEN, "≈ 9–10 min total"),
    ]
    label_w, x0, y0 = 430, 500, 70
    scale = 600 / 600
    for i, (name, a, b, bg, col, note) in enumerate(phases):
        y = y0 + i * 38
        s.text(x0 - 14, y + 18, name, size=12.5, anchor="end", weight="600")
        s.box(x0 + a * scale, y, max((b - a) * scale, 10), 26, fill=bg, stroke=col, r=4)
        s.text(x0 + b * scale + 8, y + 18, note, size=11, fill=col, anchor="start")
    ay = y0 + len(phases) * 38 + 8
    s.line(x0, ay, x0 + 600 * scale, ay, stroke=LINE)
    for m in range(0, 11):
        xx = x0 + m * 60 * scale
        s.line(xx, ay, xx, ay + 6, stroke=LINE)
        s.text(xx, ay + 20, f"{m}", size=11, fill=MUTED)
    s.text(x0 + 300, ay + 36, "minutes since the pod went Pending", size=11, fill=MUTED)
    s.lines(600, 408, [
        "Levers, biggest first: warm the image (pre-pull DaemonSet, faster gp3 root volume, ECR pull-through cache),",
        "keep weights off the critical path (PVC / S3 / bake into image), and keep one spare replica warm.",
    ], size=12, fill=MUTED, lh=17)
    s.save(HERE / "cold-start.svg")


# ---------------------------------------------------------------- 4. run of show
def run_of_show():
    s = SVG(1300, 340)
    s.text(650, 30, "Run of show — 3 h 30 min", size=18, weight="700")
    segs = [
        (["Go"], 0, 5, GRAY_BG, MUTED),
        (["M1", "Why GPUs", "are hard"], 5, 25, BLUE_BG, BLUE),
        (["M2 · Lab 1", "GPU-ready EKS"], 25, 75, GREEN_BG, GREEN),
        (["Break"], 75, 85, GRAY_BG, MUTED),
        (["M3", "Scheduling", "& sharing"], 85, 125, BLUE_BG, BLUE),
        (["M4 · Lab 2", "Serve a real model"], 125, 175, GREEN_BG, GREEN),
        (["M5", "Observability", "& cost"], 175, 200, AMBER_BG, AMBER),
        (["M6", "Wrap-up"], 200, 215, GRAY_BG, MUTED),
    ]
    scale = 1200 / 215
    x0, y0 = 50, 100
    for lines, a, b, bg, col in segs:
        s.box(x0 + a * scale, y0, (b - a) * scale - 3, 70, fill=bg, stroke=col, r=6)
        cy = y0 + 35 - (len(lines) - 1) * 8 + 4
        s.lines(x0 + (a + b) / 2 * scale - 1.5, cy, lines, size=11.5, weight="600", fill=col, lh=16)
        s.text(x0 + a * scale + 4, y0 + 90, f"{b - a} min", size=11, fill=MUTED, anchor="start")
    ay = y0 + 110
    s.line(x0, ay, x0 + 215 * scale, ay)
    for m in range(0, 216, 30):
        xx = x0 + m * scale
        s.line(xx, ay, xx, ay + 6)
        h, mm = divmod(m, 60)
        s.text(xx, ay + 20, f"{h}:{mm:02d}", size=11, fill=MUTED)
    marks = [(68, "Checkpoint 1: nvidia-smi on screen"), (122, "Checkpoint 2: 4 pods on 1 GPU"), (136, "Checkpoint 3: a completion from your endpoint")]
    for i, (m, label) in enumerate(marks):
        xx = x0 + m * scale
        top = y0 - 8 - (14 if i % 2 else 0)
        s.line(xx, top, xx, y0 + 70, stroke=RED, dash="4,3", sw=1.5)
        s.text(xx, top - 6, label, size=10.5, fill=RED, weight="600")
    s.text(650, 300, "Checkpoints 1 and 3 are hard gates: nobody moves on without the artifact on screen. TAs sweep during the buffer built into each lab.", size=12, fill=MUTED)
    s.save(HERE / "run-of-show.svg")


# ---------------------------------------------------------------- diagrams-lib architecture
def architecture():
    from diagrams import Cluster, Diagram, Edge
    from diagrams.aws.compute import EC2, EKS
    from diagrams.aws.network import VPC
    from diagrams.custom import Custom
    from diagrams.k8s.clusterconfig import HPA
    from diagrams.k8s.compute import DaemonSet, Deployment, Job, Pod
    from diagrams.k8s.network import Service
    from diagrams.k8s.others import CRD
    from diagrams.onprem.monitoring import Grafana, Prometheus

    gpu_png = str(HERE / "gpu-icon.png")
    common = dict(show=False, outformat="png", direction="LR",
                  graph_attr={"fontsize": "20", "pad": "0.4", "nodesep": "0.5", "ranksep": "0.7", "bgcolor": "white"})

    # base stack
    with Diagram("Base stack (pre-work): what Terraform deploys", filename=str(HERE / "base-stack"), **{**common, "direction": "TB"}):
        with Cluster("VPC · 3 AZs · private subnets tagged karpenter.sh/discovery"):
            cp = EKS("EKS control plane\nKubernetes 1.36")
            with Cluster("System node group (2× m6i.xlarge, CPU only)"):
                karp = Deployment("Karpenter\nv1.14")
                prom = Prometheus("Prometheus\n(kube-prometheus-stack)")
                graf = Grafana("Grafana")
                keda = Deployment("KEDA\n2.20")
                dns = Deployment("CoreDNS · metrics-server\nEKS add-ons")
            with Cluster("GPU NodePool — EMPTY until Lab 1", graph_attr={"style": "dashed", "color": "#9ca3af"}):
                gpu = Custom("g5 / g6 nodes\n(none yet)", gpu_png)
        cp >> Edge(color="#9ca3af") >> [karp, prom, graf, keda, dns]
        karp >> Edge(style="dashed", label="provisions on demand") >> gpu

    # module 3 topology
    with Diagram("Module 3 mini-lab: a shared node and an exclusive node", filename=str(HERE / "m3-topology"), **{**common, "direction": "TB"}):
        with Cluster("Node A — labeled nvidia.com/device-plugin.config=four-way\ncapacity nvidia.com/gpu: 4 (one physical A10G/L4)"):
            gpua = Custom("1 GPU\n4 time slices", gpu_png)
            pods = [Pod("shared-load-1"), Pod("shared-load-2"), Pod("shared-load-3"), Pod("shared-load-4")]
            for p in pods:
                p >> Edge(color="#d97706") >> gpua
        with Cluster("Node B — no label, launched by Karpenter for the 5th pod\ncapacity nvidia.com/gpu: 1"):
            gpub = Custom("1 GPU\nexclusive", gpu_png)
            nb = Pod("forgotten-notebook\n(sleep infinity)")
            nb >> Edge(color="#059669") >> gpub

    # autoscale loop
    with Diagram("Lab 2: the autoscaling loop", filename=str(HERE / "autoscale-loop"), **common):
        k6 = Job("k6 load\n24 virtual users")
        svc = Service("Service vllm")
        with Cluster("Deployment vllm (GPU nodes)"):
            v1 = Pod("vllm-1\nnode A, warm")
            v2 = Pod("vllm-2\n(new)")
        prom = Prometheus("Prometheus\nvllm:num_requests_*")
        keda = Deployment("KEDA\nScaledObject")
        hpa = HPA("HPA\n(owned by KEDA)")
        karp = Deployment("Karpenter")
        node = Custom("new GPU node", gpu_png)
        k6 >> svc >> [v1, v2]
        v1 >> Edge(style="dashed", label="/metrics") >> prom
        prom >> Edge(label="in-flight > 12/replica") >> keda >> hpa >> Edge(label="replicas 1→2") >> v2
        v2 >> Edge(style="dashed", label="Pending") >> karp >> node

    # observability pipeline
    with Diagram("Module 5: what feeds the dashboards", filename=str(HERE / "observability"), **common):
        with Cluster("Every GPU node"):
            dcgm = DaemonSet("dcgm-exporter\n:9400 DCGM_FI_*")
            vllm = Pod("vllm\n:8000/metrics vllm:*")
        prom = Prometheus("Prometheus")
        graf = Grafana("Grafana\nDCGM 12239 · vLLM serving")
        keda = Deployment("KEDA")
        dcgm >> Edge(label="ServiceMonitor") >> prom
        vllm >> Edge(label="PodMonitor") >> prom
        prom >> graf
        prom >> Edge(style="dashed", label="scaling queries") >> keda


if __name__ == "__main__":
    gpu_icon(HERE / "gpu-icon.png")
    gpu_stack()
    sharing_options()
    cold_start()
    run_of_show()
    architecture()
    print("diagrams written to", HERE)
