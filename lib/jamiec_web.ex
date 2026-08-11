defmodule JamieWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use JamieWeb, :controller
      use JamieWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths,
    do:
      ~w(assets fonts images favicon.ico favicon-16x16.png favicon-32x32.png apple-touch-icon.png android-chrome-192x192.png android-chrome-512x512.png site.webmanifest llms.txt robots.txt humans.txt .well-known)

  @doc """
  Filename prefixes for the root-level static files, used by `Plug.Static`'s
  `:only_matching`.

  Two lists are needed because `:only` matches a path segment *exactly*. In
  production `mix phx.digest` renames root files to `favicon-<hash>.ico`, and
  `~p"/favicon.ico"` resolves to that digested name - which never matches the
  plain `favicon.ico` in `static_paths/0`, so the request 404s before it ever
  reaches the file. `:only_matching` matches on prefix instead, so it covers
  both the plain and the digested name. Files under a directory already in
  `static_paths/0` (assets, fonts, images) are fine, as the directory segment
  matches exactly.
  """
  def static_prefixes,
    do: ~w(favicon apple-touch-icon android-chrome site llms robots humans)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: JamieWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: JamieWeb.Gettext

      import JamieWeb.CoreComponents
      import JamieWeb.SiteComponents

      alias JamieWeb.Layouts
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components

      # Common modules used in templates
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: JamieWeb.Endpoint,
        router: JamieWeb.Router,
        statics: JamieWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
