defmodule Agents.Pipeline.Application.Behaviours.SessionReopenerBehaviour do
  @moduledoc false

  @callback reopen(map()) :: :ok | {:error, term()}
end
