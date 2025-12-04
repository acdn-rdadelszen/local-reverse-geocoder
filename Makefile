DOCKER_REPO_NAME := gcr.io/npav-172917/

ifndef DOCKERFILE_TARGET
$(error DOCKERFILE_TARGET is not set, cannot determine which Dockerfile to make)
endif

ifndef CONTAINER_REGISTRY
$(error CONTAINER_REGISTRY is not set, cannot determine where this image will be pushed)
endif

HELM_APPLICATION_NAME := weld-reverse-geocoder

PWD := $(shell pwd)

UNAME := $(shell uname -m)
LOCAL_BUILD_PLATFORM := linux/amd64
ifeq ($(UNAME),arm64)
	LOCAL_BUILD_PLATFORM = linux/arm64/v8
endif
BUILD_PLATFORMS ?= linux/amd64
# BUILD_PLATFORMS ?= linux/amd64,linux/arm64/v8

dockerbin: .FORCE

docker: dockerbin
	echo "building with $(LOCAL_BUILD_PLATFORM)"
	docker buildx build --platform $(LOCAL_BUILD_PLATFORM) -t $(DOCKER_REPO_NAME)$(CONTAINER_REGISTRY):$(DOCKER_VER) --load --file $(DOCKERFILE_TARGET) .

push: dockerbin
	echo "building with $(BUILD_PLATFORMS)"
	docker buildx build --provenance=false --platform $(BUILD_PLATFORMS) -t $(DOCKER_REPO_NAME)$(CONTAINER_REGISTRY):$(DOCKER_VER) --file $(DOCKERFILE_TARGET) --push .

circleci-push:
	echo "building with $(BUILD_PLATFORMS)"
	docker buildx build --platform $(BUILD_PLATFORMS) -t $(DOCKER_REPO_NAME)$(CONTAINER_REGISTRY):$(DOCKER_VER) --file $(DOCKERFILE_TARGET) --push .

circleci-docker:
	echo "building with $(BUILD_PLATFORMS)"
	docker buildx build --platform $(LOCAL_BUILD_PLATFORM) -t $(DOCKER_REPO_NAME)$(CONTAINER_REGISTRY):$(DOCKER_VER) --load --file $(DOCKERFILE_TARGET) --progress=plain --no-cache .

circleci-push-latest:
	echo "building and pushing latest with $(BUILD_PLATFORMS)"
	docker buildx build --platform $(BUILD_PLATFORMS) -t $(DOCKER_REPO_NAME)$(CONTAINER_REGISTRY):latest --file $(DOCKERFILE_TARGET) --push .

helm-lint: helm/Chart.yaml helm/values.yaml
	helm lint helm

helm $(HELM_APPLICATION_NAME)-$(DOCKER_VER).tgz: .FORCE helm-lint $(PACKAGE_PATH)/helm/Chart.yaml $(PACKAGE_PATH)/helm/values.yaml
	@echo "Using 'version: $(DOCKER_VER)' for 'application: $(HELM_APPLICATION_NAME)' in package '$(PACKAGE_PATH)'"
	helm package $(PACKAGE_PATH)/helm

helm-push: $(HELM_APPLICATION_NAME)-$(DOCKER_VER).tgz
	helm push $< $(HELM_REPO)

.PHONY: helm helm-lint helm-push clean docker push circleci-push dockerbin

.FORCE:
clean:
	rm -rf $(POST_BUILD_CLEANUP_DIR)

# Make commands for targets in monorepo to reduce number of arguments gcr.io/npav-172917/weld-reverse-geocoder
