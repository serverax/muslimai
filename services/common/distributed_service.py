import os
import time
from typing import Dict, Any

try:
    from fastapi import FastAPI, Request, HTTPException
    from fastapi.responses import JSONResponse
except Exception as exc:
    raise RuntimeError(
        "FastAPI is required in the backend image. Install fastapi/uvicorn or use the existing backend runtime."
    ) from exc

SERVICE_NAME = os.getenv("SERVICE_NAME", "unknown-service")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", "8080"))
SERVICE_KIND = os.getenv("SERVICE_KIND", "internal")
REQUIRE_REAL_WIRING = os.getenv("REQUIRE_REAL_WIRING", "true").lower() == "true"
REAL_SERVICE_WIRED = os.getenv("REAL_SERVICE_WIRED", "false").lower() == "true"

app = FastAPI(title=SERVICE_NAME, version=os.getenv("GIT_SHA", "local"))

STARTED_AT = time.time()

@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": SERVICE_NAME,
        "kind": SERVICE_KIND,
        "uptime_seconds": round(time.time() - STARTED_AT, 2),
    }

@app.get("/ready")
def ready() -> Dict[str, Any]:
    if REQUIRE_REAL_WIRING and not REAL_SERVICE_WIRED:
        raise HTTPException(
            status_code=503,
            detail={
                "status": "not_ready",
                "service": SERVICE_NAME,
                "reason": "REAL_SERVICE_WIRED=false. Business logic must be connected before signoff.",
            },
        )
    return {
        "status": "ready",
        "service": SERVICE_NAME,
        "real_service_wired": REAL_SERVICE_WIRED,
    }

@app.get("/version")
def version() -> Dict[str, Any]:
    return {
        "service": SERVICE_NAME,
        "version": os.getenv("GIT_SHA", "unknown"),
        "image": os.getenv("IMAGE_NAME", "unknown"),
        "model": os.getenv("OLLAMA_MODEL", ""),
    }

@app.middleware("http")
async def require_trace_id(request: Request, call_next):
    if request.url.path in ["/health", "/ready", "/version"]:
        return await call_next(request)

    trace_id = request.headers.get("x-trace-id")
    if not trace_id:
        return JSONResponse(
            status_code=400,
            content={
                "error": "missing_trace_id",
                "service": SERVICE_NAME,
                "required_header": "x-trace-id",
            },
        )

    response = await call_next(request)
    response.headers["x-trace-id"] = trace_id
    response.headers["x-sakina-service"] = SERVICE_NAME
    return response

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def not_wired(path: str):
    raise HTTPException(
        status_code=501,
        detail={
            "service": SERVICE_NAME,
            "status": "not_implemented",
            "message": "This distributed service exists but its business route is not wired yet. Do not sign off.",
            "path": path,
        },
    )
