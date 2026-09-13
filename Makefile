# GPU workshop — one Makefile to rule the labs. Works with GNU make 3.81 (macOS).
#
#   make preflight        check tools, credentials, quota, base stack
#   make base-up          terraform apply the base stack (pre-work, ~20 min)
#   make lab1 / lab2      apply everything a lab does (for reruns; do it by hand in the session)
#   make workshop-down    delete workloads + GPU nodes, then terraform destroy
#
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

AWS_REGION ?= us-east-1
TF_DIR := terraform
export AWS_REGION

help: ## show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

preflight: ## verify tools, AWS credentials, GPU quota and the base stack
	@./scripts/preflight.sh

check-quota: ## show the two G-family vCPU quotas (WANT_VCPUS=n to change the target)
	@./scripts/check-quota.sh

request-quota: ## request 32 vCPUs for On-Demand G and Spot G
	@./scripts/check-quota.sh --request

base-up: ## terraform apply the base stack (VPC, EKS, Karpenter, monitoring, KEDA)
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve
	@./scripts/write-env.sh
	@$(MAKE) kubeconfig

base-down: ## terraform destroy the base stack (run teardown first if GPU nodes exist)
	cd $(TF_DIR) && terraform destroy -auto-approve

kubeconfig: ## point kubectl at the workshop cluster
	@cd $(TF_DIR) && eval "$$(terraform output -raw configure_kubectl)" && kubectl get nodes

env: ## (re)write .workshop.env from terraform outputs
	@./scripts/write-env.sh

ami-version: ## print the current recommended AL2023 NVIDIA AMI release to pin (and record it in .workshop.env)
	@./scripts/ami-version.sh

lab1: ## Lab 1 unattended: NodePool + EC2NodeClass, GPU Operator, smoke pod
	@./scripts/lab1.sh

lab2: ## Lab 2 unattended: vLLM, Service, PodMonitor, dashboard, ScaledObject (no load jobs)
	@./scripts/lab2.sh

baseline: ## 60-second k6 baseline against a single replica
	kubectl -n vllm delete job k6-baseline --ignore-not-found
	kubectl apply -f modules/04-vllm/k6-baseline-job.yaml
	@until kubectl -n vllm get pod -l app=k6-baseline -o name 2>/dev/null | grep -q .; do sleep 1; done
	kubectl -n vllm wait --for=condition=ready pod -l app=k6-baseline --timeout=120s
	kubectl -n vllm logs -f job/k6-baseline

load-test: ## 15-minute k6 load job (the autoscaling run)
	kubectl -n vllm delete job k6-load --ignore-not-found
	kubectl apply -f modules/04-vllm/k6-job.yaml
	@until kubectl -n vllm get pod -l app=k6-load -o name 2>/dev/null | grep -q .; do sleep 1; done
	kubectl -n vllm wait --for=condition=ready pod -l app=k6-load --timeout=120s
	kubectl -n vllm logs -f job/k6-load

grafana: ## port-forward Grafana to http://localhost:3000
	@echo "Grafana → http://localhost:3000  (user: admin, password: $$(cd $(TF_DIR) && terraform output -raw grafana_admin_password))"
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

teardown: ## delete workloads, GPU nodes and the GPU Operator (keeps the base stack)
	@./scripts/teardown.sh

workshop-up: base-up lab1 lab2 ## everything, end to end (~35 min)

workshop-down: teardown base-down ## everything gone

.PHONY: help preflight check-quota request-quota base-up base-down kubeconfig env ami-version lab1 lab2 baseline load-test grafana teardown workshop-up workshop-down
