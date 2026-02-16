defmodule Agents.Infrastructure.Services.LlmClient do
  @moduledoc """
  Client for interacting with LLM APIs via OpenRouter.

  Uses Google Gemini Flash 2.0 Lite by default for fast, cost-effective responses.
  Supports both synchronous and streaming responses.

  This is in the Infrastructure layer because it performs I/O operations (HTTP calls).
  """

  @behaviour Agents.Application.Behaviours.LlmClientBehaviour

  require Logger

  @default_model "google/gemini-2.5-flash-lite"
  @default_base_url "https://openrouter.ai/api/v1"
  @default_timeout 30_000

  @doc """
  Sends a chat completion request to the LLM.

  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Keyword list of options
      - :model - Model to use (default: gemini-2.0-flash-exp:free)
      - :api_key - OpenRouter API key (default: from config)
      - :base_url - OpenRouter base URL
      - :timeout - Request timeout in ms

  ## Examples

      iex> messages = [%{role: "user", content: "Hello!"}]
      iex> LlmClient.chat(messages)
      {:ok, "Hello! How can I help you today?"}

  """
  @spec chat(list(map()), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, config(:chat_model, @default_model))
    api_key = Keyword.get(opts, :api_key, config(:api_key))
    base_url = Keyword.get(opts, :base_url, config(:base_url, @default_base_url))
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    if is_nil(api_key) do
      {:error, "OpenRouter API key not configured"}
    else
      do_chat(messages, model, api_key, base_url, timeout)
    end
  end

  @doc """
  Streams a chat completion response in chunks.

  Sends chunks to the caller process as `{:chunk, text}` messages,
  and a final `{:done, full_text}` message when complete.

  ## Parameters
    - messages: List of message maps
    - caller_pid: Process to send chunks to
    - opts: Same as chat/2

  ## Returns
    {:ok, pid} of the streaming process

  ## Example

      iex> {:ok, _pid} = LlmClient.chat_stream(messages, self())
      iex> receive do
      ...>   {:chunk, text} -> IO.puts(text)
      ...> end

  """
  @impl true
  @spec chat_stream(list(map()), pid(), keyword()) :: {:ok, pid()} | {:error, String.t()}
  def chat_stream(messages, caller_pid, opts \\ []) do
    model = Keyword.get(opts, :model, config(:chat_model, @default_model))
    api_key = Keyword.get(opts, :api_key, config(:api_key))
    base_url = Keyword.get(opts, :base_url, config(:base_url, @default_base_url))

    if is_nil(api_key) do
      {:error, "OpenRouter API key not configured"}
    else
      pid =
        spawn_link(fn ->
          do_chat_stream(messages, model, api_key, base_url, caller_pid)
        end)

      {:ok, pid}
    end
  end

  # Private functions

  defp do_chat(messages, model, api_key, base_url, timeout) do
    url = "#{base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", config(:site_url, "https://jarga.ai")},
      {"X-Title", config(:app_name, "Jarga")}
    ]

    body = %{
      model: model,
      messages: messages,
      stream: false
    }

    case Req.post(url, json: body, headers: headers, receive_timeout: timeout) do
      {:ok, %{status: 200, body: response_body}} ->
        extract_content(response_body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("LLM API error: #{status} - #{inspect(body)}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        Logger.error("LLM request failed: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp do_chat_stream(messages, model, api_key, base_url, caller_pid) do
    url = "#{base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", config(:site_url, "https://jarga.ai")},
      {"X-Title", config(:app_name, "Jarga")}
    ]

    body = %{
      model: model,
      messages: messages,
      stream: true
    }

    accumulated = []

    case Req.post(url, json: body, headers: headers, into: :self) do
      {:ok, %{status: 200}} ->
        handle_stream_response(caller_pid, accumulated)

      {:ok, %{status: status}} ->
        send(caller_pid, {:error, "API error: #{status}"})

      {:error, reason} ->
        send(caller_pid, {:error, "Request failed: #{inspect(reason)}"})
    end
  end

  defp handle_stream_response(caller_pid, accumulated) do
    receive do
      {_ref, {:data, data}} ->
        # Parse SSE format: "data: {json}\n\n"
        lines = String.split(data, "\n")

        new_accumulated =
          Enum.reduce(lines, accumulated, fn line, acc ->
            case parse_sse_line(line) do
              {:ok, chunk} ->
                send(caller_pid, {:chunk, chunk})
                [chunk | acc]

              :done ->
                acc

              :skip ->
                acc
            end
          end)

        handle_stream_response(caller_pid, new_accumulated)

      {_ref, :done} ->
        full_text = accumulated |> Enum.reverse() |> Enum.join()
        send(caller_pid, {:done, full_text})
    after
      30_000 ->
        send(caller_pid, {:error, "Stream timeout"})
    end
  end

  defp parse_sse_line("data: " <> json_str) do
    if String.trim(json_str) == "[DONE]" do
      :done
    else
      case Jason.decode(json_str) do
        {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}}
        when is_binary(content) ->
          {:ok, content}

        {:ok, _} ->
          :skip

        {:error, _} ->
          :skip
      end
    end
  end

  defp parse_sse_line(_), do: :skip

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    {:ok, content}
  end

  defp extract_content(response) do
    Logger.error("Unexpected response format: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end

  defp config(key, default \\ nil) do
    Application.get_env(:agents, :openrouter, [])
    |> Keyword.get(key, default)
  end
end
