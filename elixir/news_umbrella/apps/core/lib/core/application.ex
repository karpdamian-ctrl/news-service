defmodule Core.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Core.Repo,
        {Finch, name: Core.Finch},
        {Task.Supervisor, name: Core.Search.TaskSupervisor},
        {Core.Search.EventWorker, []}
      ] ++ content_renderer_children() ++ rate_limiter_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp content_renderer_children do
    enabled? =
      Application.get_env(:core, Core.ContentRenderer.QueueConsumer, [])
      |> Keyword.get(:enabled, true)

    if enabled? do
      [{Core.ContentRenderer.QueueConsumer, []}]
    else
      []
    end
  end

  defp rate_limiter_children do
    enabled? =
      Application.get_env(:core, Core.RateLimiter, [])
      |> Keyword.get(:enabled, true)

    if enabled? do
      redis_url =
        Application.get_env(:core, :integrations, [])
        |> Keyword.get(:redis_url, "redis://localhost:6379")

      [
        {Redix, {redis_url, [name: Core.RateLimiter.Redis]}},
        {Core.RateLimiter, []}
      ]
    else
      []
    end
  end
end
