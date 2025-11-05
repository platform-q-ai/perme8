defmodule Jarga.Credo.Check.Architecture.NoCrossContextSchemaAccessTest do
  use ExUnit.Case

  alias Jarga.Credo.Check.Architecture.NoCrossContextSchemaAccess
  alias Credo.SourceFile

  test "reports violation when context accesses another context's schema via Repo.get" do
    source = """
    defmodule Jarga.Pages do
      alias Jarga.Repo
      alias Jarga.Notes.Note

      def get_page_note(note_id) do
        Repo.get!(Note, note_id)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages.ex")
    assert length(issues) > 0
    assert Enum.any?(issues, &(&1.message =~ "Notes.get_"))
  end

  test "reports violation when context accesses another context's schema with full module path" do
    source = """
    defmodule Jarga.Pages do
      alias Jarga.Repo

      def get_page_note(note_id) do
        Repo.get!(Jarga.Notes.Note, note_id)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages.ex")
    assert length(issues) > 0
    assert Enum.any?(issues, &(&1.message =~ "Notes.get_"))
  end

  test "reports violation for Repo.get_by with cross-context schema" do
    source = """
    defmodule Jarga.Pages do
      alias Jarga.Repo

      def find_note(email) do
        Repo.get_by(Jarga.Accounts.User, email: email)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages.ex")
    assert length(issues) > 0
    assert Enum.any?(issues, &(&1.message =~ "Accounts.get_"))
  end

  test "does not report when context accesses its own schema" do
    source = """
    defmodule Jarga.Pages do
      alias Jarga.Repo
      alias Jarga.Pages.Page

      def get_page(page_id) do
        Repo.get!(Page, page_id)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages.ex")
    assert [] == issues
  end

  test "does not report when in web layer" do
    source = """
    defmodule JargaWeb.PageLive do
      alias Jarga.Repo
      alias Jarga.Notes.Note

      def mount(_params, _session, socket) do
        Repo.get!(Note, 1)
      end
    end
    """

    issues = run_check(source, "lib/jarga_web/live/page_live.ex")
    assert [] == issues
  end

  test "does not report when in infrastructure layer" do
    source = """
    defmodule Jarga.Pages.Infrastructure.ComponentRepository do
      alias Jarga.Repo
      alias Jarga.Notes.Note

      def get_note_component(note_id) do
        Repo.get!(Note, note_id)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages/infrastructure/component_repository.ex")
    assert [] == issues
  end

  test "does not report when using context public API" do
    source = """
    defmodule Jarga.Pages do
      alias Jarga.Notes

      def get_page_note(note_id) do
        Notes.get_note_by_id(note_id)
      end
    end
    """

    issues = run_check(source, "lib/jarga/pages.ex")
    assert [] == issues
  end

  defp run_check(source, filename) do
    source
    |> SourceFile.parse(filename)
    |> NoCrossContextSchemaAccess.run([])
  end
end
