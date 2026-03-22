defmodule Agents.Pipeline.Infrastructure.Repositories.PullRequestRepository do
  @moduledoc "Persistence operations for internal pull requests, comments, and reviews."

  @behaviour Agents.Pipeline.Application.Behaviours.PullRequestRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema
  alias Agents.Pipeline.Infrastructure.Schemas.ReviewCommentSchema
  alias Agents.Pipeline.Infrastructure.Schemas.ReviewSchema
  alias Agents.Repo

  @preloads [comments: [], reviews: []]

  @spec create_pull_request(map(), module()) ::
          {:ok, PullRequestSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_pull_request(attrs, repo \\ Repo) do
    attrs = Map.put_new(attrs, :number, next_number(repo))

    %PullRequestSchema{}
    |> PullRequestSchema.changeset(attrs)
    |> repo.insert()
    |> preload_result(repo)
  end

  @spec get_by_number(integer(), module()) :: {:ok, PullRequestSchema.t()} | {:error, :not_found}
  def get_by_number(number, repo \\ Repo) when is_integer(number) do
    case repo.get_by(PullRequestSchema, number: number) do
      nil -> {:error, :not_found}
      pr -> {:ok, repo.preload(pr, @preloads)}
    end
  end

  @spec get_by_linked_ticket(integer(), module()) ::
          {:ok, PullRequestSchema.t()} | {:error, :not_found}
  def get_by_linked_ticket(ticket_number, repo \\ Repo) when is_integer(ticket_number) do
    case repo.get_by(PullRequestSchema, linked_ticket: ticket_number) do
      nil -> {:error, :not_found}
      pr -> {:ok, repo.preload(pr, @preloads)}
    end
  end

  @spec list_filtered(keyword(), module()) :: [PullRequestSchema.t()]
  def list_filtered(opts \\ [], repo \\ Repo) do
    per_page = Keyword.get(opts, :per_page, 30)

    PullRequestSchema
    |> maybe_filter_state(opts[:state])
    |> maybe_filter_query(opts[:query])
    |> order_by([pr], desc: pr.number)
    |> limit(^per_page)
    |> preload(^@preloads)
    |> repo.all()
  end

  @spec update_pull_request(integer(), map(), module()) ::
          {:ok, PullRequestSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_pull_request(number, attrs, repo \\ Repo) when is_integer(number) do
    case repo.get_by(PullRequestSchema, number: number) do
      nil ->
        {:error, :not_found}

      pr ->
        pr
        |> PullRequestSchema.changeset(attrs)
        |> repo.update()
        |> preload_result(repo)
    end
  end

  @spec add_comment(integer(), map(), module()) ::
          {:ok, ReviewCommentSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def add_comment(number, attrs, repo \\ Repo) when is_integer(number) do
    case repo.get_by(PullRequestSchema, number: number) do
      nil ->
        {:error, :not_found}

      pr ->
        with :ok <- validate_parent_comment(attrs, pr.id, repo) do
          %ReviewCommentSchema{}
          |> ReviewCommentSchema.changeset(Map.put(attrs, :pull_request_id, pr.id))
          |> repo.insert()
        end
    end
  end

  @spec resolve_comment_thread(integer(), Ecto.UUID.t(), String.t(), module()) ::
          {:ok, ReviewCommentSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def resolve_comment_thread(number, comment_id, actor_id, repo \\ Repo)
      when is_integer(number) and is_binary(comment_id) and is_binary(actor_id) do
    with {:ok, pr} <- get_by_number(number, repo),
         %ReviewCommentSchema{} = comment <- repo.get(ReviewCommentSchema, comment_id),
         true <- comment.pull_request_id == pr.id do
      comment
      |> ReviewCommentSchema.changeset(%{
        resolved: true,
        resolved_at: DateTime.utc_now() |> DateTime.truncate(:second),
        resolved_by: actor_id
      })
      |> repo.update()
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_found}
      {:error, :not_found} = error -> error
    end
  end

  @spec add_review(integer(), map(), module()) ::
          {:ok, ReviewSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def add_review(number, attrs, repo \\ Repo) when is_integer(number) do
    case repo.get_by(PullRequestSchema, number: number) do
      nil ->
        {:error, :not_found}

      pr ->
        attrs =
          Map.put_new(attrs, :submitted_at, DateTime.utc_now() |> DateTime.truncate(:second))

        %ReviewSchema{}
        |> ReviewSchema.changeset(Map.put(attrs, :pull_request_id, pr.id))
        |> repo.insert()
    end
  end

  @spec next_number(module()) :: integer()
  def next_number(repo \\ Repo) do
    (repo.one(from(pr in PullRequestSchema, select: max(pr.number))) || 0) + 1
  end

  defp preload_result({:ok, pr}, repo), do: {:ok, repo.preload(pr, @preloads)}
  defp preload_result(error, _repo), do: error

  defp maybe_filter_state(query, nil), do: query
  defp maybe_filter_state(query, ""), do: query
  defp maybe_filter_state(query, state), do: where(query, [pr], pr.status == ^state)

  defp maybe_filter_query(query, nil), do: query
  defp maybe_filter_query(query, ""), do: query

  defp maybe_filter_query(query, text) do
    pattern = "%#{text}%"
    where(query, [pr], ilike(pr.title, ^pattern))
  end

  defp validate_parent_comment(attrs, pull_request_id, repo) do
    case Map.get(attrs, :parent_comment_id) || Map.get(attrs, "parent_comment_id") do
      nil ->
        :ok

      parent_comment_id ->
        case repo.get(ReviewCommentSchema, parent_comment_id) do
          %ReviewCommentSchema{pull_request_id: ^pull_request_id} -> :ok
          _ -> {:error, :not_found}
        end
    end
  end
end
