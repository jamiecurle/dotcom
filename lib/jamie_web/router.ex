defmodule JamieWeb.Router do
  use JamieWeb, :router

  import JamieWeb.UserAuth

  pipeline :browser do
    plug JamieWeb.Plugs.MarkdownNegotiation
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JamieWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug JamieWeb.Plugs.LinkHeaders
  end

  pipeline :office do
    plug :put_root_layout, html: {JamieWeb.Layouts, :office_root}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JamieWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/health", PageController, :health
    get "/about", PageController, :about
    get "/privacy", PageController, :privacy
    get "/projects", PageController, :projects
    get "/feed.xml", FeedController, :index
    get "/sitemap.xml", SitemapController, :index
    get "/posts/:slug/markdown", PostMarkdownController, :show
    get "/.well-known/api-catalog", ApiCatalogController, :index

    live_session :public,
      on_mount: [{JamieWeb.UserAuth, :mount_current_scope}] do
      live "/posts", BlogLive.Index, :index
      live "/posts/:slug", BlogLive.Post, :post
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", JamieWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:jamie, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JamieWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authenticated routes
  scope "/office", JamieWeb do
    pipe_through [:browser, :require_authenticated_user, :office]

    live_session :require_authenticated_user,
      # live_session :foo,
      on_mount: [{JamieWeb.UserAuth, :require_authenticated}] do
      live "/posts/", BlogLive.OfficeIndexLive, :index
      live "/posts/new", BlogLive.Form, :new
      live "/posts/:id", BlogLive.Form, :edit
    end
  end

  scope "/", JamieWeb do
    pipe_through [:browser]

    live_session :current_user,
      root_layout: {JamieWeb.Layouts, :auth},
      on_mount: [{JamieWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
