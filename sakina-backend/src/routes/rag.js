const notImplemented = (res, detail) => {
  res.status(501).json({
    status: "not_implemented",
    feature: "rag",
    detail,
    sources: [],
  });
};

function registerRagRoutes(app) {
  if (!app || typeof app.post !== "function" || typeof app.get !== "function") {
    throw new TypeError("registerRagRoutes expects an Express-style app");
  }

  app.get("/rag/status", (_req, res) => {
    notImplemented(res, "RAG route stub installed; retrieval is not yet implemented here.");
  });

  app.get("/rag/search", (_req, res) => {
    notImplemented(res, "Semantic search is not yet implemented.");
  });

  app.post("/rag/query", (_req, res) => {
    notImplemented(res, "RAG query is not yet implemented.");
  });

  app.post("/rag/ingest", (_req, res) => {
    notImplemented(res, "Document ingestion is not yet implemented.");
  });

  return app;
}

module.exports = {
  registerRagRoutes,
  notImplemented,
};
