.PHONY: help setup-k8s dev-start dev-stop deploy load-image health clean

help:
	@echo "Sakina Infrastructure Commands"

setup-k8s:
	@echo "Creating Kubernetes cluster..."
	kind create cluster --name sakina
	kubectl create namespace sakina-data
	kubectl create namespace sakina-api
	kubectl create namespace sakina-core
	kubectl create namespace sakina-audit
	@echo "Cluster ready"

dev-start:
	@echo "Starting development services..."
	kubectl create configmap postgres-init \
		--from-file=init.sql=../sakina-backend/db/init.sql \
		-n sakina-data --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f manifests/storage-class.yaml
	kubectl apply -f manifests/postgres-deployment.yaml
	kubectl apply -f manifests/qdrant-deployment.yaml
	@echo "Services starting"

dev-stop:
	@echo "Stopping development services..."
	kubectl delete -f manifests/qdrant-deployment.yaml --ignore-not-found
	kubectl delete -f manifests/postgres-deployment.yaml --ignore-not-found
	@echo "Services stopped"

deploy:
	@echo "Deploying all services..."
	kubectl apply -R -f manifests/
	@echo "Deployment complete"
	@echo "If sakina-api pods show ErrImageNeverPull, run: make load-image"

load-image:
	docker build -f ../sakina-backend/Dockerfile.api -t sakina-backend-api:latest ../sakina-backend
	kind load docker-image sakina-backend-api:latest --name sakina

health:
	@echo "Checking service health..."
	kubectl get pods -A
	@echo "Health check complete"

clean:
	@echo "Cleaning up..."
	kind delete cluster --name sakina
	@echo "Cleanup complete"
