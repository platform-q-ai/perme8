defmodule AgentsApi.SkillApiJSON do
  @moduledoc """
  JSON rendering for Skill API endpoints.
  """

  @doc """
  Renders a list of skills.
  """
  def index(%{skills: skills}) do
    %{data: Enum.map(skills, &skill_data/1)}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp skill_data(skill) do
    %{
      name: skill.name,
      description: skill.description
    }
  end
end
