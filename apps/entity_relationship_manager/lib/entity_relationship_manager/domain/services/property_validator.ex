defmodule EntityRelationshipManager.Domain.Services.PropertyValidator do
  @moduledoc """
  Domain service for validating entity/edge properties against their definitions.

  Validates property values against their type definitions and constraints.
  This is a pure function module with no I/O dependencies.

  ## Supported Types

  - `:string` - Constraints: `min_length`, `max_length`, `pattern`, `enum`
  - `:integer` - Constraints: `min`, `max`, `enum`
  - `:float` - Constraints: `min`, `max`, `enum`
  - `:boolean` - No constraints
  - `:datetime` - ISO8601 format validation

  ## Error Format

  Errors are returned as a list of maps with:
  - `field` - The property name
  - `message` - Human-readable error message
  - `constraint` - The constraint type that failed (e.g., `:required`, `:type`, `:min_length`)
  """

  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  @type error :: %{field: String.t(), message: String.t(), constraint: atom()}
  @type validation_result :: {:ok, map()} | {:error, [error()]}

  @doc """
  Validates a properties map against a list of PropertyDefinition structs.

  Returns `{:ok, validated_properties}` on success, or
  `{:error, errors}` with a list of error maps on failure.
  """
  @spec validate_properties(map(), [PropertyDefinition.t()]) :: validation_result()
  def validate_properties(properties, definitions)
      when is_map(properties) and is_list(definitions) do
    defined_names = MapSet.new(definitions, & &1.name)

    unknown_errors = validate_unknown_properties(properties, defined_names)
    required_errors = validate_required_properties(properties, definitions)
    value_errors = validate_property_values(properties, definitions)

    errors = unknown_errors ++ required_errors ++ value_errors

    if errors == [] do
      {:ok, properties}
    else
      {:error, errors}
    end
  end

  defp validate_unknown_properties(properties, defined_names) do
    properties
    |> Map.keys()
    |> Enum.reject(&MapSet.member?(defined_names, &1))
    |> Enum.map(fn name ->
      %{field: name, message: "unknown property", constraint: :unknown}
    end)
  end

  defp validate_required_properties(properties, definitions) do
    definitions
    |> Enum.filter(& &1.required)
    |> Enum.reject(&Map.has_key?(properties, &1.name))
    |> Enum.map(fn defn ->
      %{field: defn.name, message: "is required", constraint: :required}
    end)
  end

  defp validate_property_values(properties, definitions) do
    definitions
    |> Enum.flat_map(fn defn ->
      case Map.fetch(properties, defn.name) do
        {:ok, value} -> validate_value(defn.name, value, defn.type, defn.constraints)
        :error -> []
      end
    end)
  end

  defp validate_value(name, value, :string, constraints) do
    type_errors =
      if is_binary(value),
        do: [],
        else: [%{field: name, message: "must be a string", constraint: :type}]

    if type_errors != [] do
      type_errors
    else
      validate_string_constraints(name, value, constraints)
    end
  end

  defp validate_value(name, value, :integer, constraints) do
    type_errors =
      if is_integer(value),
        do: [],
        else: [%{field: name, message: "must be an integer", constraint: :type}]

    if type_errors != [] do
      type_errors
    else
      validate_numeric_constraints(name, value, constraints)
    end
  end

  defp validate_value(name, value, :float, constraints) do
    type_errors =
      if is_number(value),
        do: [],
        else: [%{field: name, message: "must be a number", constraint: :type}]

    if type_errors != [] do
      type_errors
    else
      validate_numeric_constraints(name, value, constraints)
    end
  end

  defp validate_value(name, value, :boolean, _constraints) do
    if is_boolean(value),
      do: [],
      else: [%{field: name, message: "must be a boolean", constraint: :type}]
  end

  defp validate_value(name, value, :datetime, _constraints) do
    cond do
      not is_binary(value) ->
        [%{field: name, message: "must be an ISO8601 datetime string", constraint: :type}]

      match?({:error, _}, DateTime.from_iso8601(value)) ->
        [%{field: name, message: "must be a valid ISO8601 datetime", constraint: :type}]

      true ->
        []
    end
  end

  defp validate_string_constraints(name, value, constraints) do
    errors = []

    errors = validate_min_length(errors, name, value, constraints)
    errors = validate_max_length(errors, name, value, constraints)
    errors = validate_pattern(errors, name, value, constraints)
    errors = validate_enum(errors, name, value, constraints)

    errors
  end

  defp validate_numeric_constraints(name, value, constraints) do
    errors = []

    errors = validate_min(errors, name, value, constraints)
    errors = validate_max(errors, name, value, constraints)
    errors = validate_enum(errors, name, value, constraints)

    errors
  end

  defp validate_min_length(errors, name, value, %{min_length: min}) when byte_size(value) < min do
    [
      %{field: name, message: "must be at least #{min} characters", constraint: :min_length}
      | errors
    ]
  end

  defp validate_min_length(errors, _name, _value, _constraints), do: errors

  defp validate_max_length(errors, name, value, %{max_length: max}) when byte_size(value) > max do
    [
      %{field: name, message: "must be at most #{max} characters", constraint: :max_length}
      | errors
    ]
  end

  defp validate_max_length(errors, _name, _value, _constraints), do: errors

  defp validate_pattern(errors, name, value, %{pattern: pattern}) do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        if Regex.match?(regex, value) do
          errors
        else
          [
            %{field: name, message: "must match pattern #{pattern}", constraint: :pattern}
            | errors
          ]
        end

      {:error, _} ->
        errors
    end
  end

  defp validate_pattern(errors, _name, _value, _constraints), do: errors

  defp validate_min(errors, name, value, %{min: min}) when value < min do
    [%{field: name, message: "must be at least #{min}", constraint: :min} | errors]
  end

  defp validate_min(errors, _name, _value, _constraints), do: errors

  defp validate_max(errors, name, value, %{max: max}) when value > max do
    [%{field: name, message: "must be at most #{max}", constraint: :max} | errors]
  end

  defp validate_max(errors, _name, _value, _constraints), do: errors

  defp validate_enum(errors, name, value, %{enum: allowed}) when is_list(allowed) do
    if value in allowed do
      errors
    else
      [
        %{field: name, message: "must be one of: #{Enum.join(allowed, ", ")}", constraint: :enum}
        | errors
      ]
    end
  end

  defp validate_enum(errors, _name, _value, _constraints), do: errors
end
