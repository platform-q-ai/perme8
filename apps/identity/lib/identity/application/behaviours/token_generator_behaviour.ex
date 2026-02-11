defmodule Identity.Application.Behaviours.TokenGeneratorBehaviour do
  @moduledoc """
  Behaviour defining the token generator contract.
  """

  @callback generate_random_token() :: binary()
  @callback generate_random_token(non_neg_integer()) :: binary()
  @callback hash_token(binary()) :: binary()
  @callback encode_token(binary()) :: String.t()
  @callback decode_token(String.t()) :: {:ok, binary()} | :error
  @callback rand_size() :: non_neg_integer()
end
