.PHONY: help setup-k8s dev-start dev-stop build test deploy health clean

help:
	@echo "Project Sakina - Available Commands"
	@echo "setup-k8s    - Initialize Kubernetes cluster"
	@echo "dev-start    - Start development environment"
	@echo "dev-stop     - Stop development environment"
	@echo "build        - Build all components"
	@echo "test         - Run all tests"
	@echo "deploy       - Deploy to Kubernetes"
	@echo "health       - Check service health"
	@echo "clean        - Clean artifacts"

setup-k8s:
	cd sakina-infra && make setup-k8s

dev-start:
	cd sakina-infra && make dev-start

dev-stop:
	cd sakina-infra && make dev-stop

build: build-backend build-frontend

build-backend:
	cd sakina-backend && cargo build --release

build-frontend:
	cd sakina-frontend && flutter pub get && flutter build apk --release

test: test-backend test-frontend test-integration

test-backend:
	cd sakina-backend && cargo test --verbose

test-frontend:
	cd sakina-frontend && flutter test

test-integration:
	cd sakina-tests && pytest -v

deploy:
	cd sakina-infra && make deploy

health:
	cd sakina-infra && make health

clean:
	cd sakina-backend && cargo clean
	cd sakina-frontend && flutter clean
	cd sakina-infra && make clean
	rm -rf target/
	rm -rf build/
