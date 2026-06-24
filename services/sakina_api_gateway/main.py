import os
os.environ.setdefault("SERVICE_NAME", "sakina-api-gateway")
os.environ.setdefault("SERVICE_PORT", "8080")
os.environ.setdefault("SERVICE_KIND", "api")

from services.common.distributed_service import app
