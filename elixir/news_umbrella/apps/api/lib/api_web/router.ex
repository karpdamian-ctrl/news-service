defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ApiWeb.Plugs.ApiAuditLog
    plug ApiWeb.Plugs.ApiTokenAuth
  end

  scope "/", ApiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", ApiWeb do
    pipe_through :api

    scope "/v1" do
      resources "/categories", CategoryController, except: [:new, :edit]
      resources "/tags", TagController, except: [:new, :edit]
      resources "/media", MediaController, except: [:new, :edit]
      resources "/articles", ArticleController, except: [:new, :edit]
      resources "/article-revisions", ArticleRevisionController, except: [:new, :edit]
    end
  end
end
