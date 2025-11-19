defmodule WaitForAsyncAssigns do
  @moduledoc """
  Prevents "DBConnection.ConnectionError: client exited" errors in Phoenix LiveView tests.

  When LiveView tests use async operations (`start_async`, `assign_async`), those operations
  may still be running when the test exits, causing database connection errors. This module
  provides a helper to wait for all async operations to complete before test cleanup.

  ## Installation

  Add to your `mix.exs`:

  ```elixir
  def deps do
    [
      {:wait_for_async_assigns, "~> 0.1.0", only: :test}
    ]
  end
  ```

  Then import in your test case modules:

  ```elixir
  # In test/support/conn_case.ex
  defmodule MyAppWeb.ConnCase do
    using do
      quote do
        import WaitForAsyncAssigns
      end
    end
  end
  ```

  ## Usage

  Call `wait_for_async_assigns/1` or `wait_for_async_assigns/2` at the end of any LiveView
  test that uses async operations:

  ```elixir
  test "loads data asynchronously", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    html = render_async(view)
    assert html =~ "Products"

    # Wait for async operations to complete
    wait_for_async_assigns(view)
  end
  ```

  The function can be called with or without parentheses:

  ```elixir
  wait_for_async_assigns view
  wait_for_async_assigns view, 5000
  ```

  ## Why This Is Needed

  When `render_click()` or other event handlers complete, they return immediately even if
  async work (like database queries) is still pending. The test process then begins shutdown
  while async operations are still running, causing connection errors like:

      ** (DBConnection.ConnectionError) client #PID<0.123.0> exited

  This helper monitors all async task PIDs and waits for them to exit before the test
  completes.

  ## See Also

  - [Phoenix LiveView Issue #3545](https://github.com/phoenixframework/phoenix_live_view/issues/3545)
  """

  @doc """
  Waits for all LiveView async operations to complete.

  Monitors all async task PIDs associated with the LiveView and waits for their
  `:DOWN` messages, ensuring all async work completes before the test exits.

  ## Parameters

    * `view` - The LiveView returned from `live/2`
    * `timeout` - Maximum time to wait in milliseconds (default: ExUnit's `assert_receive_timeout`)

  ## Examples

      test "loads data asynchronously", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/products")
        html = render_async(view)
        assert html =~ "Products"

        wait_for_async_assigns(view)
      end

      test "loads with custom timeout", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/slow-operation")
        html = render_async(view, 10_000)
        assert html =~ "Complete"

        wait_for_async_assigns(view, 10_000)
      end

  ## Timeout

  The default timeout matches Phoenix LiveView's `render_async/2` and ExUnit's
  `assert_receive/3`, which is configured via:

      config :ex_unit, assert_receive_timeout: 100

  You can override the timeout per-call or globally in your test configuration.
  """
  def wait_for_async_assigns(
        view,
        timeout \\ Application.fetch_env!(:ex_unit, :assert_receive_timeout)
      ) do
    import ExUnit.Assertions, only: [assert_receive: 2]

    {:ok, pids} = Phoenix.LiveView.Channel.async_pids(view.pid)

    pids
    |> Enum.map(&Process.monitor/1)
    |> Enum.each(fn ref ->
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}, timeout
    end)
  catch
    :exit, _ -> :ok
  end
end
