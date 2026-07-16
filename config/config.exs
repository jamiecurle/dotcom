# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config
alias Jamie.Service.R2

# registry pattern for dependancy injection
config :jamie, :services,
  http: Req,
  r2: R2

config :jamie, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    default: 10,
    bookmarks: 1,
    r2: 15
  ],
  repo: Jamie.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # bookmarks sync - every fifteen minutes
       {"*/15 * * * *", Jamie.Workers.SyncBookmarks, queue: :bookmarks}
     ]}
  ]

config :jamie, :scopes,
  user: [
    default: true,
    module: Jamie.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Jamie.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :jamie,
  ecto_repos: [Jamie.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :jamie, JamieWeb.Endpoint,
  url: [host: "127.0.0.1"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JamieWeb.ErrorHTML, json: JamieWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jamie.PubSub,
  live_view: [signing_salt: "ztvDy8aq"]

config :jamie, :images, transform: "cdn-cgi/image/width=1200,format=auto,quality=85"

# Register text/markdown so Plug.Conn.put_resp_content_type/3 and any
# format-aware code recognise the .md extension.
config :mime, :types, %{"text/markdown" => ["md"]}

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :jamie, Jamie.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  jamie: [
    args:
      ~w(js/app.js js/office.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  css: [
    args:
      ~w(css/app.css --bundle --outdir=../priv/static/assets/css --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure tailwind (the version is required). This ONLY builds the
# /office admin entrypoint (admin.css). The public site (app.css) is
# hand-rolled CSS bundled by esbuild above and is left untouched.
config :tailwind,
  version: "4.1.7",
  jamie: [
    args: ~w(
      --input=assets/css/admin.css
      --output=priv/static/assets/css/admin.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
