defmodule Agents.Tickets.Infrastructure.Clients.StubGithubTicketClientTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Infrastructure.Clients.StubGithubTicketClient, as: Stub

  @opts [token: "fake", org: "test-org", repo: "test-repo"]

  describe "get_issue/2" do
    test "returns known issue 1" do
      assert {:ok, issue} = Stub.get_issue(1, @opts)
      assert issue.number == 1
      assert issue.title =~ "Stub"
      assert "enhancement" in issue.labels
    end

    test "returns not_found for unknown issue" do
      assert {:error, :not_found} = Stub.get_issue(999_999, @opts)
    end
  end

  describe "list_issues/1" do
    test "returns all known issues with no filters" do
      assert {:ok, issues} = Stub.list_issues(@opts)
      assert length(issues) == 2
    end

    test "filters by state" do
      assert {:ok, issues} = Stub.list_issues([state: "open"] ++ @opts)
      assert length(issues) == 2

      assert {:ok, []} = Stub.list_issues([state: "closed"] ++ @opts)
    end

    test "filters by labels" do
      assert {:ok, issues} = Stub.list_issues([labels: ["enhancement"]] ++ @opts)
      assert length(issues) == 1
      assert hd(issues).number == 1
    end
  end

  describe "create_issue/2" do
    test "returns a new issue with given title" do
      assert {:ok, issue} = Stub.create_issue(%{title: "New thing", body: "Details"}, @opts)
      assert issue.number == 9999
      assert issue.title == "New thing"
      assert issue.state == "open"
    end
  end

  describe "update_issue/3" do
    test "updates known issue" do
      assert {:ok, issue} = Stub.update_issue(1, %{title: "Updated"}, @opts)
      assert issue.title == "Updated"
      assert issue.number == 1
    end

    test "returns not_found for unknown number" do
      assert {:error, :not_found} = Stub.update_issue(999_999, %{title: "New Title"}, @opts)
    end
  end

  describe "close_issue_with_comment/2" do
    test "closes known issue" do
      assert {:ok, issue} = Stub.close_issue_with_comment(1, [comment: "Done"] ++ @opts)
      assert issue.state == "closed"
    end

    test "returns not_found for unknown issue" do
      assert {:error, :not_found} = Stub.close_issue_with_comment(999_999, @opts)
    end
  end

  describe "add_comment/3" do
    test "adds comment to known issue" do
      assert {:ok, comment} = Stub.add_comment(1, "Hello", @opts)
      assert comment.body == "Hello"
      assert comment.url =~ "issuecomment"
    end

    test "returns not_found for unknown issue" do
      assert {:error, :not_found} = Stub.add_comment(999_999, "Nope", @opts)
    end
  end

  describe "add_sub_issue/3" do
    test "links known issues" do
      assert {:ok, result} = Stub.add_sub_issue(1, 2, @opts)
      assert result.parent_number == 1
      assert result.child_number == 2
    end

    test "returns not_found when parent unknown" do
      assert {:error, :not_found} = Stub.add_sub_issue(999_999, 2, @opts)
    end
  end

  describe "remove_sub_issue/3" do
    test "unlinks known issues" do
      assert {:ok, result} = Stub.remove_sub_issue(1, 2, @opts)
      assert result.parent_number == 1
      assert result.child_number == 2
    end

    test "returns not_found when child unknown" do
      assert {:error, :not_found} = Stub.remove_sub_issue(1, 999_999, @opts)
    end
  end
end
