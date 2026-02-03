import Config

config :neo_excel_ppt, NeoExcelPPTWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Logger level in production
config :logger, level: :info

# Runtime production config
config :neo_excel_ppt, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
