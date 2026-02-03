import Config

config :neo_excel_ppt,
  generators: [timestamp_type: :utc_datetime]

# Endpoint configuration
config :neo_excel_ppt, NeoExcelPPTWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: NeoExcelPPTWeb.ErrorHTML, json: NeoExcelPPTWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NeoExcelPPT.PubSub,
  live_view: [signing_salt: "neoExcelPPTSalt"]

# Esbuild configuration
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Tailwind configuration
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

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Phoenix JSON library
config :phoenix, :json_library, Jason

# Import environment specific config
import_config "#{config_env()}.exs"
