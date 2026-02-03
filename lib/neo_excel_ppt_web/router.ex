defmodule NeoExcelPPTWeb.Router do
  use NeoExcelPPTWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NeoExcelPPTWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NeoExcelPPTWeb do
    pipe_through :browser

    # Main project estimation page
    live "/", ProjectLive, :index

    # Skills management
    live "/skills", SkillsLive, :index
    live "/skills/:id", SkillsLive, :show

    # Event timeline
    live "/timeline", TimelineLive, :index
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:neo_excel_ppt, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NeoExcelPPTWeb.Telemetry
    end
  end
end
