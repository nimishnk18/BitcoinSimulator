defmodule BitcoinCompleteWeb.Router do
  use BitcoinCompleteWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BitcoinCompleteWeb do
    pipe_through :browser

    get "/", HomeController, :index
    post "/", HomeController, :start
  end

  # Other scopes may use custom stacks.
  # scope "/api", BitcoinCompleteWeb do
  #   pipe_through :api
  # end
end
