# Makefile for harness — Fork of harness/harness
# Provides common development, build, and test targets

SHELL := /bin/bash

# Go parameters
GO_CMD     := go
GO_BUILD   := $(GO_CMD) build
GO_TEST    := $(GO_CMD) test
GO_VET     := $(GO_CMD) vet
GO_FMT     := gofmt
GO_LINT    := golangci-lint
GO_MOD     := $(GO_CMD) mod

# Project parameters
BINARY_NAME := harness
BIN_DIR     := ./bin
CMD_DIR     := ./cmd/harness
PKG_LIST    := $(shell go list ./... 2>/dev/null | grep -v /vendor/)

# Build info
GIT_COMMIT  := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_TAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
BUILD_TIME  := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
LD_FLAGS    := -ldflags "-X main.GitCommit=$(GIT_COMMIT) -X main.Version=$(GIT_TAG) -X main.BuildTime=$(BUILD_TIME)"

.DEFAULT_GOAL := help

## help: Print this help message
.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/  /'

## build: Compile the binary into $(BIN_DIR)/$(BINARY_NAME)
.PHONY: build
build:
	@mkdir -p $(BIN_DIR)
	$(GO_BUILD) $(LD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME) $(CMD_DIR)

## build-all: Cross-compile for linux/amd64, linux/arm64, and darwin/amd64
.PHONY: build-all
build-all:
	@mkdir -p $(BIN_DIR)
	GOOS=linux  GOARCH=amd64 $(GO_BUILD) $(LD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-linux-amd64   $(CMD_DIR)
	GOOS=linux  GOARCH=arm64 $(GO_BUILD) $(LD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-linux-arm64   $(CMD_DIR)
	GOOS=darwin GOARCH=amd64 $(GO_BUILD) $(LD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-darwin-amd64  $(CMD_DIR)
	# TODO: add darwin/arm64 (Apple Silicon) once I get a chance to test it

## test: Run unit tests with race detector
.PHONY: test
test:
	$(GO_TEST) -race -count=1 -timeout 120s $(PKG_LIST)

## test-cover: Run tests and generate an HTML coverage report
.PHONY: test-cover
test-cover:
	@mkdir -p $(BIN_DIR)
	$(GO_TEST) -race -coverprofile=$(BIN_DIR)/coverage.out -covermode=atomic $(PKG_LIST)
	$(GO_CMD) tool cover -html=$(BIN_DIR)/coverage.out -o $(BIN_DIR)/coverage.html
	@echo "Coverage report: $(BIN_DIR)/coverage.html"

## lint: Run golangci-lint
.PHONY: lint
lint:
	$(GO_LINT) run ./...

## fmt: Format all Go source files
.PHONY: fmt
fmt:
	$(GO_FMT) -w $$(find . -name '*.go' -not -path './vendor/*')

## vet: Run go vet
.PHONY: vet
vet:
	$(GO_VET) ./...

## tidy: Tidy and verify go modules
.PHONY: tidy
tidy:
	$(GO_MOD) tidy
	$(GO_MOD) verify

## clean: Remove build artifacts
.PHONY: clean
clean:
	@rm -rf $(BIN_DIR)
	@echo "Cleaned $(BIN_DIR)"

## ci: Run all checks performed in CI (fmt, vet, lint, test)
# Note: skipping fmt in ci locally since my editor handles formatting on save
.PHONY: ci
ci: vet lint test
