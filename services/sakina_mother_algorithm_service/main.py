import os
os.environ.setdefault("SERVICE_NAME", "sakina-mother-algorithm-service")
os.environ.setdefault("SERVICE_PORT", "8080")
os.environ.setdefault("SERVICE_KIND", "internal")

from services.common.distributed_service import app
