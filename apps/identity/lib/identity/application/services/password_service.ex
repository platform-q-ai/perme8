defmodule Identity.Application.Services.PasswordService do
  @moduledoc """
  Password hashing and verification service using Bcrypt.

  This module wraps Bcrypt functionality to provide a clean interface
  for password hashing and verification in the application layer.

  ## Security

  - Uses Bcrypt for password hashing (industry standard)
  - Generates unique salt for each password
  - Provides timing-attack resistant verification
  - Includes dummy verification to prevent user enumeration

  ## Usage

      iex> hashed = PasswordService.hash_password("my_password")
      iex> PasswordService.verify_password("my_password", hashed)
      true

      iex> PasswordService.verify_password("wrong_password", hashed)
      false

  """

  @doc """
  Hashes a password using Bcrypt.

  Generates a unique hash for the given password with a random salt.
  Even identical passwords will produce different hashes.

  ## Parameters

    - password: The plain text password to hash (must be a binary)

  ## Returns

  A Bcrypt hash string (60 bytes, starting with "$2b$")

  ## Examples

      iex> hashed = PasswordService.hash_password("hello world!")
      iex> String.starts_with?(hashed, "$2b$")
      true

  """
  def hash_password(password) when is_binary(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @doc """
  Verifies a password against a Bcrypt hash.

  Returns true if the password matches the hash, false otherwise.
  Handles nil and empty values safely by always returning false.

  ## Parameters

    - password: The plain text password to verify
    - hashed_password: The Bcrypt hash to verify against

  ## Returns

  Boolean indicating if the password matches the hash

  ## Examples

      iex> hashed = PasswordService.hash_password("hello world!")
      iex> PasswordService.verify_password("hello world!", hashed)
      true

      iex> PasswordService.verify_password("wrong password", hashed)
      false

      iex> PasswordService.verify_password(nil, hashed)
      false

      iex> PasswordService.verify_password("hello world!", nil)
      false

  """
  def verify_password(password, hashed_password)
      when is_binary(password) and is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def verify_password(_password, _hashed_password), do: false

  @doc """
  Performs a dummy password verification to prevent timing attacks.

  This function takes roughly the same time as a real password verification
  but always returns false. Use this when a user is not found to prevent
  user enumeration through timing analysis.

  ## Returns

  Always returns false

  ## Examples

      iex> PasswordService.no_user_verify()
      false

  ## Security Note

  This is important for preventing timing attacks. When checking login
  credentials, always call either `verify_password/2` or `no_user_verify/0`
  so the response time doesn't reveal whether a user exists.

  """
  def no_user_verify do
    Bcrypt.no_user_verify()
    false
  end
end
