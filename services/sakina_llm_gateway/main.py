import os
os.environ.setdefault("SERVICE_NAME", "sakina-llm-gateway")
os.environ.setdefault("SERVICE_PORT", "8087")
os.environ.setdefault("SERVICE_KIND", "internal")

from services.common.distributed_service import app
