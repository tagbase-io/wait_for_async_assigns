if Code.ensure_loaded?(Credo.Check) do
  defmodule Credo.Check.WaitForAsyncAssignsTest do
    use Credo.Test.Case

    alias Credo.Check.WaitForAsyncAssigns

    test "it should NOT report when wait_for_async_assigns is present" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "loads products", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          assert render(view) =~ "Products"

          wait_for_async_assigns(view)
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> refute_issues()
    end

    test "it should NOT report when wait_for_async_tasks is present" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "loads products", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          assert render(view) =~ "Products"

          wait_for_async_tasks(view)
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> refute_issues()
    end

    test "it should NOT report when live/2 expects failure" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "redirects on unauthorized access", %{conn: conn} do
          assert {:error, {:redirect, redirect}} = live(conn, ~p"/products")
          assert redirect.to == "/login"
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> refute_issues()
    end

    test "it should NOT report for non-test modules" do
      """
      defmodule MyApp.SomeModule do
        def some_function do
          {:ok, view, _html} = live(conn, ~p"/products")
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> refute_issues()
    end

    test "it should report when live/2 call is missing wait_for_async_assigns" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "loads products", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          assert render(view) =~ "Products"
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> assert_issue(fn issue ->
        assert issue.message =~ "wait_for_async_assigns"
      end)
    end

    test "it should report multiple issues for multiple missing calls" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "loads products", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/products")
          assert render(view) =~ "Products"
        end

        test "loads dashboard", %{conn: conn} do
          {:ok, view, _html} = live(conn, ~p"/dashboard")
          assert render(view) =~ "Dashboard"
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> assert_issues(fn issues ->
        assert Enum.count(issues) == 2
      end)
    end

    test "it should handle tests inside describe blocks" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        describe "product list" do
          test "loads products", %{conn: conn} do
            {:ok, view, _html} = live(conn, ~p"/products")
            assert render(view) =~ "Products"
          end
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> assert_issue()
    end

    test "it should handle two-element tuple pattern {:ok, view}" do
      """
      defmodule MyAppWeb.ProductsLiveTest do
        use ExUnit.Case

        test "loads products", %{conn: conn} do
          {:ok, view} = live(conn, ~p"/products")
          assert render(view) =~ "Products"
        end
      end
      """
      |> to_source_file()
      |> run_check(WaitForAsyncAssigns)
      |> assert_issue()
    end
  end
end
