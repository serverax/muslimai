FROM python:3.11-slim

WORKDIR /app
COPY sakina-rag/src ./src
COPY sakina-rag/config ./config

RUN python -m pip install --no-cache-dir pyyaml

EXPOSE 8080
CMD ["python", "-m", "http.server", "8080"]
