defmodule Jamie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Oban emits telemetry for every job, but doesn't log it unless we attach
    # its default logger. Without this, job successes and failures (including
    # crashes) never appear in the application logs.
    :ok = Oban.Telemetry.attach_default_logger()

    children = [
      JamieWeb.Telemetry,
      Jamie.Repo,
      {DNSCluster, query: Application.get_env(:jamie, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:jamie, Oban)},
      {Phoenix.PubSub, name: Jamie.PubSub},
      # Start a worker by calling: Jamie.Worker.start_link(arg)
      # {Jamie.Worker, arg},
      # Start to serve requests, typically the last entry
      JamieWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jamie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JamieWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
