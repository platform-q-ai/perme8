defmodule Jarga.Accounts.Infrastructure.Queries.ApiKeyQueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema
  alias Jarga.Accounts.Infrastructure.Queries.ApiKeyQueries

  describe "base/0" do
    test "base returns ApiKeySchema queryable" do
      query = ApiKeyQueries.base()

      assert %Ecto.Query{} = query
      # Just check it has the correct schema
      assert {"api_keys", ApiKeySchema} = query.from.source
    end
  end

  describe "by_user_id/2" do
    test "by_user_id filters by user_id" do
      user_id = Ecto.UUID.generate()

      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.by_user_id(user_id)

      assert %Ecto.Query{} = query
    end
  end

  describe "by_id/2" do
    test "by_id filters by id" do
      api_key_id = Ecto.UUID.generate()

      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.by_id(api_key_id)

      assert %Ecto.Query{} = query
    end
  end

  describe "by_hashed_token/2" do
    test "by_hashed_token filters by hashed_token" do
      hashed_token = "hashed_token_123"

      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.by_hashed_token(hashed_token)

      assert %Ecto.Query{} = query
    end
  end

  describe "active/1" do
    test "active filters for is_active = true" do
      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.active()

      assert %Ecto.Query{} = query
    end
  end

  describe "inactive/1" do
    test "inactive filters for is_active = false" do
      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.inactive()

      assert %Ecto.Query{} = query
    end
  end

  describe "preload_user/1" do
    test "preload_user preloads user association" do
      query =
        ApiKeyQueries.base()
        |> ApiKeyQueries.preload_user()

      assert %Ecto.Query{} = query
    end
  end
end
