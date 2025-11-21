defmodule Jarga.Credo.Check.Architecture.NoSideEffectsInDomain do
  @moduledoc """
  Detects side effects in domain entities (password hashing, crypto operations).

  ## Clean Architecture Violation (Single Responsibility Principle)

  Domain entities should be pure data structures with validation logic.
  They should NOT perform:
  - Password hashing (Bcrypt.hash_pwd_salt)
  - Cryptographic operations (:crypto module calls)
  - External API calls
  - File I/O
  - Time-based operations (beyond validation)

  Per Clean Architecture: Domain entities encapsulate business rules but should
  not depend on infrastructure services like cryptography, external systems, or I/O.

  ## Why This Violates Clean Code

  1. **Single Responsibility**: Entities should validate data, not perform crypto
  2. **Dependency Inversion**: Crypto is infrastructure, domain shouldn't depend on it
  3. **Testability**: Side effects make tests slower and more complex
  4. **Portability**: Ties domain to specific crypto library (Bcrypt)

  ## Examples

  ### Invalid - Password hashing in changeset:

      defmodule Jarga.Accounts.Domain.Entities.User do
        use Ecto.Schema
        import Ecto.Changeset

        def registration_changeset(user, attrs) do
          user
          |> cast(attrs, [:email, :password])
          |> validate_password()
          |> hash_password()  # ❌ Side effect in domain
        end

        defp hash_password(changeset) do
          password = get_change(changeset, :password)
          
          if password do
            # ❌ Cryptographic operation in domain entity
            put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
          else
            changeset
          end
        end
      end

  ### Valid - Extract hashing to application layer:

      # Domain entity - pure validation
      defmodule Jarga.Accounts.Domain.Entities.User do
        use Ecto.Schema
        import Ecto.Changeset

        def registration_changeset(user, attrs) do
          user
          |> cast(attrs, [:email, :password])
          |> validate_required([:email, :password])
          |> validate_length(:password, min: 12)
        end

        # Pure function - no side effects
        def with_hashed_password(changeset, hashed_password) do
          changeset
          |> put_change(:hashed_password, hashed_password)
          |> delete_change(:password)
        end
      end

      # Infrastructure service - crypto operations
      defmodule Jarga.Accounts.Infrastructure.PasswordHasher do
        def hash_password(password) do
          Bcrypt.hash_pwd_salt(password)
        end

        def verify_password(password, hash) do
          Bcrypt.verify_pass(password, hash)
        end
      end

      # Application layer - orchestrates domain + infrastructure
      defmodule Jarga.Accounts.Application.UseCases.RegisterUser do
        alias Jarga.Accounts.Infrastructure.PasswordHasher

        def execute(params) do
          changeset = User.registration_changeset(%User{}, params)

          if changeset.valid? do
            password = get_change(changeset, :password)
            hashed = PasswordHasher.hash_password(password)
            
            changeset
            |> User.with_hashed_password(hashed)
            |> Repo.insert()
          else
            {:error, changeset}
          end
        end
      end

  ### Invalid - Token generation in domain:

      defmodule Jarga.Accounts.Domain.Entities.UserToken do
        def build_token(user) do
          # ❌ Cryptographic side effect in domain
          token = :crypto.strong_rand_bytes(32)
          hashed = :crypto.hash(:sha256, token)
          
          {token, %__MODULE__{token: hashed, user_id: user.id}}
        end
      end

  ### Valid - Extract to domain service:

      # Domain service - pure token logic (can be in domain if pure)
      defmodule Jarga.Accounts.Domain.TokenGenerator do
        @rand_size 32

        def generate_token() do
          :crypto.strong_rand_bytes(@rand_size)
        end

        def hash_token(token) do
          :crypto.hash(:sha256, token)
        end
      end

      # Or move to infrastructure if you consider crypto as infrastructure
      defmodule Jarga.Accounts.Infrastructure.TokenGenerator do
        # Same implementation
      end

  ## What's Allowed vs Not Allowed

  **Allowed (Pure Domain Logic):**
  - Validation functions (validate_*, cast)
  - Business rule checks (pure functions)
  - Data transformations (String.downcase, etc.)
  - Changesets that only manipulate data

  **Not Allowed (Side Effects):**
  - Bcrypt.hash_pwd_salt (crypto operation)
  - :crypto module calls in changesets
  - External API calls
  - File I/O operations
  - Database queries

  ## Exception

  This check allows `Bcrypt.verify_pass` in domain entities because password
  verification is a domain business rule (authentication), while hashing is
  an infrastructure concern (storage).
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Domain entities should not perform side effects like password hashing.

      Side effects include:
      - Bcrypt.hash_pwd_salt (password hashing)
      - :crypto module operations in changesets
      - External API calls
      - File I/O

      Extract these to:
      - Infrastructure services (PasswordHasher, TokenGenerator)
      - Application layer use cases (orchestrate domain + infrastructure)

      This ensures:
      - Single Responsibility Principle
      - Domain remains pure and testable
      - Infrastructure concerns isolated
      - Easy to swap crypto implementations
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check domain entity files
    if domain_entity_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp domain_entity_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/domain/entities/") and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Detect Bcrypt.hash_pwd_salt calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Bcrypt]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if function in [:hash_pwd_salt, :add_hash, :hash_password] do
        [
          issue_for(
            issue_meta,
            meta,
            "Bcrypt.#{function}",
            "Password hashing in domain entity",
            "Extract to Infrastructure.PasswordHasher service"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect :crypto module calls (strong_rand_bytes, hash)
  defp traverse(
         {{:., meta, [:crypto, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:strong_rand_bytes, :hash, :mac, :sign, :encrypt] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         ":crypto.#{function}",
         "Cryptographic operation in domain entity",
         "Extract to Infrastructure.TokenGenerator or Infrastructure.CryptoService"
       )
       | issues
     ]}
  end

  # Detect System.get_env calls (environment dependency)
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:System]}, :get_env]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "System.get_env",
         "Environment variable access in domain entity",
         "Inject configuration via function parameters or Application config"
       )
       | issues
     ]}
  end

  # Detect File module calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:File]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:read, :write, :read!, :write!] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "File.#{function}",
         "File I/O in domain entity",
         "Extract to Infrastructure.FileStorage service"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger, description, suggestion) do
    format_issue(
      issue_meta,
      message:
        "Domain entity performs side effect (#{description}). " <>
          "Domain should contain pure business logic with no infrastructure dependencies. " <>
          "#{suggestion}. " <>
          "This violates Single Responsibility Principle and makes domain harder to test (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
