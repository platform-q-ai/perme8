defmodule Perme8Tools.AffectedApps.Fixtures do
  @moduledoc """
  Shared test fixtures for affected apps tests.

  Provides the canonical Perme8 dependency map used across
  multiple test files to avoid duplication.
  """

  @doc """
  Returns the canonical dependency map matching the real Perme8 umbrella.

  Update this when the umbrella dependency structure changes.
  """
  def perme8_deps do
    %{
      perme8_events: [],
      perme8_plugs: [],
      identity: [:perme8_events, :perme8_plugs],
      agents: [:perme8_events, :perme8_plugs, :identity],
      notifications: [:perme8_events, :identity],
      chat: [:perme8_events, :identity, :agents],
      jarga: [:perme8_events, :identity, :agents, :notifications],
      entity_relationship_manager: [:perme8_events, :perme8_plugs, :jarga, :identity],
      webhooks: [:perme8_events, :identity, :jarga],
      jarga_web: [
        :perme8_events,
        :perme8_plugs,
        :jarga,
        :agents,
        :notifications,
        :chat,
        :chat_web
      ],
      jarga_api: [:jarga, :identity, :perme8_plugs],
      agents_web: [:perme8_events, :agents, :identity, :jarga],
      agents_api: [:agents, :identity, :perme8_plugs],
      chat_web: [:chat, :identity, :agents],
      webhooks_api: [:webhooks, :identity, :jarga, :perme8_plugs],
      exo_dashboard: [],
      alkali: [],
      perme8_tools: []
    }
  end

  @doc """
  Returns the list of all known app atoms.
  """
  def known_apps do
    Map.keys(perme8_deps())
  end
end
