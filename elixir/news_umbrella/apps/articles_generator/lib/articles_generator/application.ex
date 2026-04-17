defmodule ArticlesGenerator.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = children()

    opts = [strategy: :one_for_one, name: ArticlesGenerator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children do
    if Application.get_env(:articles_generator, :enabled, true) do
      redis_url = Application.fetch_env!(:articles_generator, :redis_url)

      [
        {Redix, {redis_url, [name: ArticlesGenerator.Redis]}},
        {ArticlesGenerator.Scheduler, []}
      ]
    else
      []
    end
  end
end
