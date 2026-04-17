defmodule ApiWeb.Plugs.ApiRateLimitTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  alias ApiWeb.Plugs.ApiRateLimit

  defmodule MockRateLimiter do
    def allow_request(_identifier) do
      Process.get(:rate_limiter_reply, {:ok, %{allowed: true}})
    end
  end

  setup do
    previous_enabled = Application.get_env(:api, :rate_limiter_enabled)
    previous_backend = Application.get_env(:api, :rate_limiter_backend)

    Application.put_env(:api, :rate_limiter_enabled, true)
    Application.put_env(:api, :rate_limiter_backend, MockRateLimiter)

    on_exit(fn ->
      if is_nil(previous_enabled) do
        Application.delete_env(:api, :rate_limiter_enabled)
      else
        Application.put_env(:api, :rate_limiter_enabled, previous_enabled)
      end

      if is_nil(previous_backend) do
        Application.delete_env(:api, :rate_limiter_backend)
      else
        Application.put_env(:api, :rate_limiter_backend, previous_backend)
      end
    end)

    :ok
  end

  test "passes request when limiter allows it" do
    Process.put(:rate_limiter_reply, {:ok, %{allowed: true}})

    conn =
      :get
      |> build_conn("/api/v1/categories")
      |> ApiRateLimit.call([])

    refute conn.halted
  end

  test "returns 429 when limiter blocks request" do
    Process.put(
      :rate_limiter_reply,
      {:ok, %{allowed: false, ttl: 55, limit: 100, count: 101}}
    )

    conn =
      :get
      |> build_conn("/api/v1/categories")
      |> ApiRateLimit.call([])

    assert conn.halted
    assert conn.status == 429
    assert Plug.Conn.get_resp_header(conn, "retry-after") == ["55"]

    assert %{"error" => "rate_limited", "retry_after_seconds" => 55, "limit" => 100} =
             Jason.decode!(conn.resp_body)
  end
end
