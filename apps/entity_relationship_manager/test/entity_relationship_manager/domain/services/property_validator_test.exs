defmodule EntityRelationshipManager.Domain.Services.PropertyValidatorTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Services.PropertyValidator
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  defp string_prop(name, opts \\ []) do
    PropertyDefinition.new(%{
      name: name,
      type: :string,
      required: Keyword.get(opts, :required, false),
      constraints: Keyword.get(opts, :constraints, %{})
    })
  end

  defp integer_prop(name, opts \\ []) do
    PropertyDefinition.new(%{
      name: name,
      type: :integer,
      required: Keyword.get(opts, :required, false),
      constraints: Keyword.get(opts, :constraints, %{})
    })
  end

  defp float_prop(name, opts \\ []) do
    PropertyDefinition.new(%{
      name: name,
      type: :float,
      required: Keyword.get(opts, :required, false),
      constraints: Keyword.get(opts, :constraints, %{})
    })
  end

  defp boolean_prop(name, opts \\ []) do
    PropertyDefinition.new(%{
      name: name,
      type: :boolean,
      required: Keyword.get(opts, :required, false),
      constraints: Keyword.get(opts, :constraints, %{})
    })
  end

  defp datetime_prop(name, opts \\ []) do
    PropertyDefinition.new(%{
      name: name,
      type: :datetime,
      required: Keyword.get(opts, :required, false),
      constraints: Keyword.get(opts, :constraints, %{})
    })
  end

  describe "validate_properties/2 - required fields" do
    test "returns ok when required field is present" do
      definitions = [string_prop("email", required: true)]
      properties = %{"email" => "test@example.com"}

      assert {:ok, validated} = PropertyValidator.validate_properties(properties, definitions)
      assert validated == %{"email" => "test@example.com"}
    end

    test "returns error when required field is missing" do
      definitions = [string_prop("email", required: true)]
      properties = %{}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "email" && &1.constraint == :required))
    end

    test "allows missing optional fields" do
      definitions = [string_prop("nickname")]
      properties = %{}

      assert {:ok, validated} = PropertyValidator.validate_properties(properties, definitions)
      assert validated == %{}
    end
  end

  describe "validate_properties/2 - unknown properties" do
    test "rejects unknown properties" do
      definitions = [string_prop("email")]
      properties = %{"email" => "test@example.com", "unknown_field" => "value"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "unknown_field" && &1.constraint == :unknown))
    end
  end

  describe "validate_properties/2 - string type" do
    test "validates string type" do
      definitions = [string_prop("name")]
      properties = %{"name" => "Alice"}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects non-string value for string type" do
      definitions = [string_prop("name")]
      properties = %{"name" => 42}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "name" && &1.constraint == :type))
    end

    test "validates min_length constraint" do
      definitions = [string_prop("name", constraints: %{min_length: 3})]
      properties = %{"name" => "AB"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "name" && &1.constraint == :min_length))
    end

    test "validates max_length constraint" do
      definitions = [string_prop("name", constraints: %{max_length: 5})]
      properties = %{"name" => "Too Long Name"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "name" && &1.constraint == :max_length))
    end

    test "validates pattern constraint" do
      definitions = [string_prop("email", constraints: %{pattern: "^[^@]+@[^@]+$"})]
      properties = %{"email" => "not-an-email"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "email" && &1.constraint == :pattern))
    end

    test "passes pattern constraint for valid value" do
      definitions = [string_prop("email", constraints: %{pattern: "^[^@]+@[^@]+$"})]
      properties = %{"email" => "test@example.com"}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end
  end

  describe "validate_properties/2 - integer type" do
    test "validates integer type" do
      definitions = [integer_prop("age")]
      properties = %{"age" => 25}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects non-integer value for integer type" do
      definitions = [integer_prop("age")]
      properties = %{"age" => "twenty-five"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "age" && &1.constraint == :type))
    end

    test "validates min constraint" do
      definitions = [integer_prop("age", constraints: %{min: 18})]
      properties = %{"age" => 15}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "age" && &1.constraint == :min))
    end

    test "validates max constraint" do
      definitions = [integer_prop("age", constraints: %{max: 120})]
      properties = %{"age" => 150}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "age" && &1.constraint == :max))
    end
  end

  describe "validate_properties/2 - float type" do
    test "validates float type" do
      definitions = [float_prop("score")]
      properties = %{"score" => 9.5}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "accepts integer as float" do
      definitions = [float_prop("score")]
      properties = %{"score" => 10}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects non-numeric value for float type" do
      definitions = [float_prop("score")]
      properties = %{"score" => "high"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "score" && &1.constraint == :type))
    end

    test "validates min constraint" do
      definitions = [float_prop("score", constraints: %{min: 0.0})]
      properties = %{"score" => -1.5}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "score" && &1.constraint == :min))
    end

    test "validates max constraint" do
      definitions = [float_prop("score", constraints: %{max: 10.0})]
      properties = %{"score" => 11.0}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "score" && &1.constraint == :max))
    end
  end

  describe "validate_properties/2 - boolean type" do
    test "validates boolean type" do
      definitions = [boolean_prop("active")]
      properties = %{"active" => true}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "accepts false as boolean" do
      definitions = [boolean_prop("active")]
      properties = %{"active" => false}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects non-boolean value" do
      definitions = [boolean_prop("active")]
      properties = %{"active" => "yes"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "active" && &1.constraint == :type))
    end
  end

  describe "validate_properties/2 - datetime type" do
    test "validates ISO8601 datetime string" do
      definitions = [datetime_prop("created")]
      properties = %{"created" => "2024-01-15T10:30:00Z"}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects invalid datetime format" do
      definitions = [datetime_prop("created")]
      properties = %{"created" => "not-a-date"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "created" && &1.constraint == :type))
    end

    test "rejects non-string value for datetime" do
      definitions = [datetime_prop("created")]
      properties = %{"created" => 12_345}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "created" && &1.constraint == :type))
    end
  end

  describe "validate_properties/2 - enum constraint" do
    test "validates enum constraint for string" do
      definitions = [
        string_prop("status", constraints: %{enum: ["active", "inactive", "pending"]})
      ]

      properties = %{"status" => "active"}

      assert {:ok, _} = PropertyValidator.validate_properties(properties, definitions)
    end

    test "rejects value not in enum" do
      definitions = [
        string_prop("status", constraints: %{enum: ["active", "inactive", "pending"]})
      ]

      properties = %{"status" => "unknown"}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert Enum.any?(errors, &(&1.field == "status" && &1.constraint == :enum))
    end
  end

  describe "validate_properties/2 - multiple errors" do
    test "collects multiple errors" do
      definitions = [
        string_prop("email", required: true),
        integer_prop("age", required: true, constraints: %{min: 0})
      ]

      properties = %{"age" => -5}

      assert {:error, errors} = PropertyValidator.validate_properties(properties, definitions)
      assert length(errors) >= 2

      assert Enum.any?(errors, &(&1.field == "email" && &1.constraint == :required))
      assert Enum.any?(errors, &(&1.field == "age" && &1.constraint == :min))
    end
  end

  describe "validate_properties/2 - empty input" do
    test "validates empty properties against no definitions" do
      assert {:ok, %{}} = PropertyValidator.validate_properties(%{}, [])
    end
  end
end
