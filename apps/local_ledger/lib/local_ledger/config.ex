defmodule LocalLedger.Config do
  @moduledoc """
  Provides a configuration function that are called during application startup.
  """

  def read_scheduler_config do
    case System.get_env("BALANCE_CACHING_FREQUENCY") do
      nil -> []
      frequency -> [{frequency, {LocalLedger.CachedBalance, :cache_all, []}}]
    end
  end
end
