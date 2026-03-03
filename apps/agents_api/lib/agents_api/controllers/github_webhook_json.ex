defmodule AgentsApi.GithubWebhookJSON do
  @moduledoc false

  def queued(%{details: details}) do
    %{status: "queued", details: details}
  end

  def ignored(_assigns) do
    %{status: "ignored"}
  end

  def error(%{message: message}) do
    %{error: message}
  end
end
