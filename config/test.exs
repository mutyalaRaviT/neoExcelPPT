import Config

config :neo_excel_ppt, NeoExcelPPTWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_testing_only",
  server: true

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
