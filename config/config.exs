import Config

config :neo_excel_ppt,
  generators: [timestamp_type: :utc_datetime]

config :neo_excel_ppt, NeoExcelPPTWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: NeoExcelPPTWeb.ErrorHTML, json: NeoExcelPPTWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NeoExcelPPT.PubSub,
  live_view: [signing_salt: "skills_actors_salt"]

# LiveSvelte configuration
config :live_svelte,
  # Disable SSR for simpler setup (can enable later with Node.js)
  ssr: false

config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
