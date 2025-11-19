if Code.ensure_loaded?(Credo.Check) do
  defmodule Credo.Check.WaitForAsyncAssigns do
    @moduledoc """
    Ensures that LiveView tests using `live/2` include `wait_for_async_assigns/1` call.

    This check prevents "DBConnection.ConnectionError: client exited" warnings by ensuring
    all async work completes before the test exits.

    ## Why This Is Important

    LiveView tests that use async operations (start_async, assign_async) must wait for
    those operations to complete before the test exits. Without this, async database
    queries may still be running when the test process shuts down, causing connection
    errors.

    ## What It Checks

    For any test file that:
    1. Contains a successful `live(conn, ...)` call pattern matched with `{:ok, view, ...}`
    2. Does NOT contain a `wait_for_async_assigns(view)` call after it

    The check will report this as an issue.

    ## What It Ignores

    Tests that expect `live/2` to fail (e.g., redirects, errors) are not flagged:

        # Not flagged - expects error
        assert {:error, {:redirect, redirect}} = live(conn, ~p"/path")

    ## Example

        # Bad - missing wait_for_async_assigns
        test "loads data", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          html = render_async(view)
          assert html =~ "Products"
        end

        # Good - includes wait_for_async_assigns
        test "loads data", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          html = render_async(view)
          assert html =~ "Products"

          wait_for_async_assigns(view)
        end

    ## Configuration

    Add this check to your `.credo.exs`:

        %{
          configs: [
            %{
              name: "default",
              requires: ["deps/wait_for_async_assigns/lib/credo/check/wait_for_async_assigns.ex"],
              checks: %{
                enabled: [
                  {Credo.Check.WaitForAsyncAssigns, []}
                ]
              }
            }
          ]
        }

    Note: This check is only available if Credo is installed. The package does not
    require Credo as a dependency.
    """

    use Credo.Check, base_priority: :high, category: :warning

    alias Credo.Code

    @explanation [check: @moduledoc]
    @default_params []

    @doc false
    @impl true
    def run(source_file, params \\ []) do
      issue_meta = IssueMeta.for(source_file, params)

      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end

    defp traverse({:defmodule, _meta, [{:__aliases__, _, module_name_parts}, [do: module_body]]} = ast, issues, issue_meta) do
      module_name = Enum.map_join(module_name_parts, ".", &Atom.to_string/1)

      if String.ends_with?(module_name, "Test") do
        new_issues = check_module_tests(module_body, issue_meta)
        {ast, issues ++ new_issues}
      else
        {ast, issues}
      end
    end

    defp traverse(ast, issues, _issue_meta) do
      {ast, issues}
    end

    defp check_module_tests({:__block__, _, expressions}, issue_meta) do
      expressions
      |> Enum.flat_map(&extract_tests/1)
      |> Enum.flat_map(&check_test(&1, issue_meta))
    end

    defp check_module_tests(_, _issue_meta), do: []

    defp extract_tests({:test, meta, [_name, _context, [do: body]]}) do
      [{meta, body}]
    end

    defp extract_tests({:describe, _, [_description, [do: block]]}) do
      case block do
        {:__block__, _, expressions} ->
          Enum.flat_map(expressions, &extract_tests/1)

        single_expr ->
          extract_tests(single_expr)
      end
    end

    defp extract_tests(_), do: []

    defp check_test({meta, body}, issue_meta) do
      has_successful_live_call = has_successful_live_call?(body)
      has_wait_call = has_wait_for_async_assigns?(body)

      if has_successful_live_call and not has_wait_call do
        [issue_for(issue_meta, meta[:line])]
      else
        []
      end
    end

    defp has_successful_live_call?(ast) do
      {_ast, found} =
        Macro.prewalk(ast, false, fn
          {:=, _, [{:{}, _, [:ok | _]}, {:live, _, [_conn | _]}]} = node, _acc ->
            {node, true}

          {:=, _, [{:ok, _view}, {:live, _, [_conn | _]}]} = node, _acc ->
            {node, true}

          node, acc ->
            {node, acc}
        end)

      found
    end

    defp has_wait_for_async_assigns?(ast) do
      {_ast, found} =
        Macro.prewalk(ast, false, fn
          {:wait_for_async_assigns, _, [_view | _]} = node, _acc -> {node, true}
          {:wait_for_async_tasks, _, [_view | _]} = node, _acc -> {node, true}
          node, acc -> {node, acc}
        end)

      found
    end

    defp issue_for(issue_meta, line_no) do
      format_issue(
        issue_meta,
        message: "LiveView test using `live/2` should call `wait_for_async_assigns/1` to prevent connection errors.",
        line_no: line_no
      )
    end
  end
end
