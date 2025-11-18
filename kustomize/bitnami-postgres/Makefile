# Makefile for Bitnami PostgreSQL on AKS
# Simplifies common deployment and management tasks

.PHONY: help preview-base deploy-base preview-prod deploy-prod verify clean test-connection

# Default target
help:
	@echo "Bitnami PostgreSQL on AKS - Available targets:"
	@echo ""
	@echo "  preview-base      - Preview base (standalone) deployment"
	@echo "  deploy-base       - Deploy base (standalone) configuration"
	@echo "  preview-prod      - Preview production (HA) deployment"
	@echo "  deploy-prod       - Deploy production (HA) configuration"
	@echo "  verify            - Verify deployment status"
	@echo "  test-connection   - Test database connection"
	@echo "  create-secret     - Create postgres credentials secret"
	@echo "  backup-now        - Trigger manual backup"
	@echo "  logs              - Show PostgreSQL logs"
	@echo "  clean             - Remove all resources"
	@echo ""

# Namespace
NAMESPACE ?= postgres

# Preview base deployment
preview-base:
	@echo "Previewing base deployment..."
	kustomize build base --enable-helm

# Deploy base configuration
deploy-base:
	@echo "Deploying base configuration..."
	kustomize build base --enable-helm | kubectl apply -f -
	@echo "Waiting for deployment to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n $(NAMESPACE) --timeout=300s

# Preview production deployment
preview-prod:
	@echo "Previewing production deployment..."
	kustomize build overlays/production --enable-helm

# Deploy production configuration
deploy-prod:
	@echo "Deploying production configuration..."
	kustomize build overlays/production --enable-helm | kubectl apply -f -
	@echo "Waiting for primary to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=primary -n $(NAMESPACE) --timeout=300s
	@echo "Waiting for read replicas to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=read -n $(NAMESPACE) --timeout=300s

# Create namespace and secret
create-secret:
	@echo "Creating namespace..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "Generating random passwords..."
	@POSTGRES_PASSWORD=$$(openssl rand -base64 32); \
	APP_PASSWORD=$$(openssl rand -base64 32); \
	REPL_PASSWORD=$$(openssl rand -base64 32); \
	kubectl create secret generic postgres-credentials \
		--from-literal=postgres-password="$$POSTGRES_PASSWORD" \
		--from-literal=password="$$APP_PASSWORD" \
		--from-literal=replication-password="$$REPL_PASSWORD" \
		--namespace=$(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Secret created successfully"

# Verify deployment
verify:
	@echo "Checking pods..."
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "Checking services..."
	kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "Checking PVCs..."
	kubectl get pvc -n $(NAMESPACE)
	@echo ""
	@echo "Checking StatefulSets..."
	kubectl get statefulset -n $(NAMESPACE)

# Test database connection
test-connection:
	@echo "Testing database connection..."
	@export POSTGRES_PASSWORD=$$(kubectl get secret --namespace $(NAMESPACE) postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d); \
	kubectl run postgres-client --rm --tty -i --restart='Never' \
		--namespace $(NAMESPACE) \
		--image registry-1.docker.io/bitnami/postgresql:16 \
		--env="PGPASSWORD=$$POSTGRES_PASSWORD" \
		--command -- psql -h postgres-postgresql -U postgres -d appdb -c "SELECT version();"

# View logs
logs:
	@echo "Showing PostgreSQL primary logs..."
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=primary --tail=50 -f

# Trigger manual backup
backup-now:
	@echo "Triggering manual backup..."
	@BACKUP_NAME=manual-backup-$$(date +%s); \
	kubectl create job --from=cronjob/postgres-postgresql-backup $$BACKUP_NAME -n $(NAMESPACE); \
	echo "Backup job created: $$BACKUP_NAME"; \
	kubectl wait --for=condition=complete job/$$BACKUP_NAME -n $(NAMESPACE) --timeout=600s || \
	kubectl logs -n $(NAMESPACE) job/$$BACKUP_NAME

# Port forward for local access
port-forward:
	@echo "Port forwarding to localhost:5432..."
	@export POSTGRES_PASSWORD=$$(kubectl get secret --namespace $(NAMESPACE) postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d); \
	echo "PostgreSQL password: $$POSTGRES_PASSWORD"; \
	kubectl port-forward --namespace $(NAMESPACE) svc/postgres-postgresql 5432:5432

# Scale read replicas (production only)
scale-replicas:
	@read -p "Enter number of read replicas: " replicas; \
	kubectl scale statefulset postgres-postgresql-read --replicas=$$replicas -n $(NAMESPACE)

# Clean up all resources
clean:
	@echo "WARNING: This will delete all PostgreSQL resources including data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Deleting resources..."; \
		kustomize build base --enable-helm | kubectl delete -f - --ignore-not-found; \
		kubectl delete pvc -n $(NAMESPACE) --all; \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found; \
		echo "Cleanup complete"; \
	else \
		echo "Cleanup cancelled"; \
	fi

# Show metrics
metrics:
	@echo "PostgreSQL metrics endpoint:"
	kubectl port-forward -n $(NAMESPACE) svc/postgres-postgresql-metrics 9187:9187 &
	@sleep 2
	@curl -s http://localhost:9187/metrics | grep -E "^pg_" | head -20
	@pkill -f "port-forward.*9187"

# Get connection string
connection-string:
	@echo "PostgreSQL connection details:"
	@echo "Host: postgres-postgresql.$(NAMESPACE).svc.cluster.local"
	@echo "Port: 5432"
	@echo "Database: appdb"
	@echo "User: postgres"
	@echo -n "Password: "
	@kubectl get secret --namespace $(NAMESPACE) postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d
	@echo ""

# Health check
health:
	@echo "Checking PostgreSQL health..."
	@kubectl exec -n $(NAMESPACE) -it postgres-postgresql-primary-0 -- pg_isready -U postgres

# Describe resources for troubleshooting
describe:
	@echo "Describing StatefulSets..."
	kubectl describe statefulset -n $(NAMESPACE)
	@echo ""
	@echo "Describing Pods..."
	kubectl describe pods -n $(NAMESPACE)

# Restart PostgreSQL (rolling restart)
restart:
	@echo "Performing rolling restart..."
	kubectl rollout restart statefulset -n $(NAMESPACE)
	kubectl rollout status statefulset -n $(NAMESPACE)
