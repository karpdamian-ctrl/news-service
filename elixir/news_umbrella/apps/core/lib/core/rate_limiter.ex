defmodule Core.RateLimiter do
  @moduledoc false

  use GenServer

  @default_limit 100
  @default_window_seconds 60
  @default_key_prefix "api_rate_limit"

  @script """
  local current = redis.call("INCR", KEYS[1])
  if current == 1 then
    redis.call("EXPIRE", KEYS[1], ARGV[1])
  end
  local ttl = redis.call("TTL", KEYS[1])
  return {current, ttl}
  """

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow_request(identifier) when is_binary(identifier) and byte_size(identifier) > 0 do
    GenServer.call(__MODULE__, {:allow_request, identifier})
  end

  def allow_request(_identifier), do: {:error, :invalid_identifier}

  @impl true
  def init(_state) do
    config = Application.get_env(:core, __MODULE__, [])

    {:ok,
     %{
       redis_name: Keyword.get(config, :redis_name, Core.RateLimiter.Redis),
       limit: Keyword.get(config, :limit, @default_limit),
       window_seconds: Keyword.get(config, :window_seconds, @default_window_seconds),
       key_prefix: Keyword.get(config, :key_prefix, @default_key_prefix)
     }}
  end

  @impl true
  def handle_call({:allow_request, identifier}, _from, state) do
    key = "#{state.key_prefix}:#{identifier}"

    command = [
      "EVAL",
      @script,
      "1",
      key,
      Integer.to_string(state.window_seconds)
    ]

    response =
      case Redix.command(state.redis_name, command) do
        {:ok, [count, ttl]} when is_integer(count) and is_integer(ttl) ->
          {:ok,
           %{
             allowed: count <= state.limit,
             count: count,
             limit: state.limit,
             ttl: max(ttl, 0)
           }}

        {:ok, other} ->
          {:error, {:invalid_response, other}}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, response, state}
  end
end
