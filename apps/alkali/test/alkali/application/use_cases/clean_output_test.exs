defmodule Alkali.Application.UseCases.CleanOutputTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.UseCases.CleanOutput

  describe "execute/1" do
    test "deletes the output directory" do
      output_path = "_site"

      # Simple function mock - no Mox needed
      file_system = fn
        {:rm_rf, ^output_path} -> :ok
      end

      assert :ok = CleanOutput.execute(output_path, file_system: file_system)
    end

    test "succeeds even if directory doesn't exist" do
      output_path = "_site"

      file_system = fn
        {:rm_rf, ^output_path} -> :ok
      end

      assert :ok = CleanOutput.execute(output_path, file_system: file_system)
    end

    test "returns error if deletion fails" do
      output_path = "_site"

      file_system = fn
        {:rm_rf, ^output_path} -> {:error, :eacces}
      end

      assert {:error, :eacces} = CleanOutput.execute(output_path, file_system: file_system)
    end

    test "uses default output directory if not specified" do
      file_system = fn
        {:rm_rf, "_site"} -> :ok
      end

      assert :ok = CleanOutput.execute(file_system: file_system)
    end
  end
end
