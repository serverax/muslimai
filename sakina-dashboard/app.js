/* Sakina moderation dashboard (Step 14). Vue 3 via CDN; reads the API's
   /v1/dashboard/guardrails endpoint. Override the base via window.SAKINA_API_BASE. */
const { createApp } = Vue;

const API_BASE = window.SAKINA_API_BASE || "http://localhost:8080/v1";

createApp({
  data() {
    return { guardrails: [], loading: false, error: "" };
  },
  mounted() {
    this.refresh();
  },
  methods: {
    async refresh() {
      this.loading = true;
      this.error = "";
      try {
        const res = await fetch(`${API_BASE}/dashboard/guardrails`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        this.guardrails = Array.isArray(data) ? data : [];
      } catch (e) {
        this.error = `Failed to load guardrails: ${e.message}`;
      } finally {
        this.loading = false;
      }
    },
  },
}).mount("#app");
