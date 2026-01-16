defmodule Jarga.Credo.Check.Architecture.UseCaseAdoptionTest do
  @moduledoc """
  Tests for the UseCaseAdoption Credo check.

  This test ensures the check correctly identifies when context modules
  contain complex business logic that should be extracted to use cases.
  """

  use ExUnit.Case

  alias Jarga.Credo.Check.Architecture.UseCaseAdoption
  alias Credo.SourceFile

  describe "run/2" do
    test "reports no issues for simple context functions" do
      source = """
      defmodule Jarga.SomeContext do
        alias Jarga.Repo

        def get_item(id) do
          Repo.get(Item, id)
        end

        def list_items do
          Repo.all(Item)
        end
      end
      """

      assert [] == run_check(source)
    end

    test "reports issues for Ecto.Multi usage in context" do
      source = """
      defmodule Jarga.Pages do
        import Ecto.Multi
        alias Jarga.Repo

        def create_page(user, workspace_id, attrs) do
          Multi.new()
          |> Multi.insert(:page, changeset)
          |> Multi.run(:note, fn repo, %{page: page} ->
            create_note(page)
          end)
          |> Repo.transaction()
        end
      end
      """

      issues = run_check(source)
      assert length(issues) > 0

      assert Enum.any?(issues, fn issue ->
               issue.message =~ "Multi.new()" and
                 issue.message =~ "use case"
             end)
    end

    test "reports issues for complex with chains in context (5+ clauses)" do
      source = """
      defmodule Jarga.Projects do
        def create_project(user, attrs) do
          with {:ok, workspace} <- verify_membership(user),
               :ok <- validate_permissions(user),
               :ok <- check_quota(workspace),
               {:ok, slug} <- generate_slug(attrs),
               {:ok, project} <- insert_project(attrs),
               {:ok, _notification} <- notify_team(project) do
            {:ok, project}
          end
        end
      end
      """

      issues = run_check(source)
      assert length(issues) > 0

      assert Enum.any?(issues, fn issue ->
               issue.message =~ "Complex with statement" and
                 issue.message =~ "use case"
             end)
    end

    test "allows simple with chains (4 or fewer clauses)" do
      source = """
      defmodule Jarga.Projects do
        def update_project(id, attrs) do
          with {:ok, project} <- get_project(id),
               :ok <- validate_attrs(attrs),
               {:ok, updated} <- save_project(project, attrs) do
            {:ok, updated}
          end
        end
      end
      """

      assert [] == run_check(source)
    end

    test "reports issues for transaction blocks in context" do
      source = """
      defmodule Jarga.Workspaces do
        def invite_member(email, workspace_id) do
          Repo.transaction(fn ->
            user = get_or_create_user(email)
            member = create_membership(user, workspace_id)
            send_invitation(member)
            member
          end)
        end
      end
      """

      issues = run_check(source)
      assert length(issues) > 0

      assert Enum.any?(issues, fn issue ->
               issue.message =~ "Repo.transaction" and
                 issue.message =~ "use case"
             end)
    end

    test "allows contexts with use case delegations" do
      source = """
      defmodule Jarga.Projects do
        alias Jarga.Projects.Application.UseCases.CreateProject

        def create_project(user, workspace_id, attrs) do
          CreateProject.execute(%{
            actor: user,
            workspace_id: workspace_id,
            attrs: attrs
          })
        end
      end
      """

      assert [] == run_check(source)
    end

    test "ignores use case modules themselves" do
      source = """
      defmodule Jarga.Projects.UseCases.CreateProject do
        import Ecto.Multi

        def execute(params) do
          Multi.new()
          |> Multi.insert(:project, changeset)
          |> Repo.transaction()
        end
      end
      """

      assert [] == run_check(source)
    end

    test "ignores non-context modules" do
      source = """
      defmodule JargaWeb.PageController do
        import Ecto.Multi

        def create(conn, params) do
          Multi.new()
          |> Multi.insert(:page, changeset)
          |> Repo.transaction()
        end
      end
      """

      assert [] == run_check(source)
    end

    test "reports issues for multi-run orchestration patterns" do
      source = """
      defmodule Jarga.Pages do
        def create_page_with_components(attrs) do
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:page, page_changeset(attrs))
          |> Ecto.Multi.run(:note, fn repo, %{page: page} ->
            create_note_for_page(repo, page)
          end)
          |> Ecto.Multi.run(:components, fn repo, changes ->
            create_components(repo, changes)
          end)
          |> Repo.transaction()
        end
      end
      """

      issues = run_check(source)
      assert length(issues) > 0
    end

    test "provides helpful error message" do
      source = """
      defmodule Jarga.SomeContext do
        def complex_operation(attrs) do
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:item, changeset)
          |> Repo.transaction()
        end
      end
      """

      issues = run_check(source)
      assert length(issues) == 1
      [issue] = issues

      assert issue.message =~ "Complex orchestration logic"
      assert issue.message =~ "use case"
      assert issue.message =~ "CreateOperation"
      assert issue.trigger == "Multi.new()"
    end
  end

  defp run_check(source) do
    source
    |> SourceFile.parse("test.ex")
    |> UseCaseAdoption.run([])
  end
end
