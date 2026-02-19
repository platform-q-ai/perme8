defmodule AgentsApi.Test.Fixtures do
  @moduledoc """
  Test fixtures for the Agents API app.
  """

  use Boundary,
    top_level?: true,
    deps: [Identity, Identity.Repo, Agents],
    exports: []

  alias Identity.Infrastructure.Schemas.ApiKeySchema
  alias Identity.Infrastructure.Schemas.UserSchema
  alias Identity.Application.Services.ApiKeyTokenService
  alias Identity.Application.Services.PasswordService
  alias Identity.Domain.Entities.User

  @doc """
  Creates a confirmed user for testing.
  """
  def user_fixture(attrs \\ %{}) do
    user_attrs =
      Enum.into(attrs, %{
        email: "user#{System.unique_integer([:positive])}@example.com",
        first_name: "Test",
        last_name: "User"
      })

    {:ok, user} = Identity.register_user(user_attrs)

    # Confirm the user via magic link
    token =
      extract_user_token(fn url ->
        Identity.deliver_login_instructions(user, url)
      end)

    {:ok, {_confirmed_user, _expired}} = Identity.login_user_by_magic_link(token)

    # Set a hashed password for completeness
    hashed_password = PasswordService.hash_password("hello world!")

    updated =
      user
      |> UserSchema.to_schema()
      |> Ecto.Changeset.change(hashed_password: hashed_password)
      |> Identity.Repo.update!()

    User.from_schema(updated)
  end

  @doc """
  Creates an API key for a user, returning {api_key_entity, plain_token}.
  """
  def api_key_fixture(user_id, attrs \\ %{}) do
    plain_token = ApiKeyTokenService.generate_token()
    hashed_token = ApiKeyTokenService.hash_token(plain_token)

    api_key_attrs = %{
      name: Map.get(attrs, :name, "Test API Key"),
      description: Map.get(attrs, :description),
      hashed_token: hashed_token,
      user_id: user_id,
      workspace_access: Map.get(attrs, :workspace_access, []),
      is_active: Map.get(attrs, :is_active, true)
    }

    {:ok, schema} =
      %ApiKeySchema{}
      |> ApiKeySchema.changeset(api_key_attrs)
      |> Identity.Repo.insert()

    api_key = ApiKeySchema.to_entity(schema)
    {api_key, plain_token}
  end

  @doc """
  Creates an agent for a user.
  """
  def agent_fixture(user_id, attrs \\ %{}) do
    agent_attrs =
      Map.merge(
        %{
          "user_id" => user_id,
          "name" => "Test Agent #{System.unique_integer([:positive])}"
        },
        attrs
      )

    {:ok, agent} = Agents.create_user_agent(agent_attrs)
    agent
  end

  defp extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
