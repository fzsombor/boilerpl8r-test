SHELL := /bin/bash

R_IMAGE_BASE := registry.example.net/flink-assignment/repo_name
BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD | sed 's/[^a-zA-Z0-9\-\.]/-/g')
LATEST_COMMIT_HASH := $(shell git log -1 --oneline | cut -d' ' -f1)
IMAGE_TAG  := $(IMAGE_BASE):$(BRANCH_NAME)-$(LATEST_COMMIT_HASH)
LATEST_TAG := $(IMAGE_BASE):latest
R_PROD_JOB_MANAGER := JOB_MANAGER_SUBDOMAIN.example.net


.PHONY:	build
build:
	docker build -t $(IMAGE_TAG) -t $(LATEST_TAG) .

.PHONY:	push
push:	build
	docker push $(IMAGE_TAG)
	docker push $(LATEST_TAG)

.PHONY:	deploy-prod-cluster
deploy-prod-cluster:
		./deploy-to-k8s.sh flink-cluster prod $(IMAGE_TAG)

