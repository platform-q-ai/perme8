defmodule Agents.Test.TicketSyncServerTestClient do
  @moduledoc false

  use Agent

  def start_link(opts) do
    responses = Keyword.get(opts, :responses, [])
    Agent.start_link(fn -> responses end, name: __MODULE__)
  end

  def fetch_tickets(_opts) do
    Agent.get_and_update(__MODULE__, fn
      [next | rest] -> {next, rest}
      [] -> {{:ok, []}, []}
    end)
  end

  def close_issue(_issue_number, _opts), do: :ok
end
