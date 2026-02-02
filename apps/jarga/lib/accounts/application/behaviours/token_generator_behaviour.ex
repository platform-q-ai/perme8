defmodule Jarga.Accounts.Application.Behaviours.TokenGeneratorBehaviour do
  @moduledoc """
  Behaviour defining the token generator contract.
  """

  @callback generate_token() :: String.t()
  @callback hash_token(String.t()) :: String.t()
  @callback build_session_token(map()) :: String.t()
  @callback build_email_token(map(), String.t()) :: {String.t(), String.t()}
end
