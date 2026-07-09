defmodule Jamie.Service do
  @moduledoc """
  Service discovery for the project
  """

  @doc """
  Get a service or blow up.
  """
  def get!(service) do
    Application.fetch_env!(:jamie, :services)[service]
  end
end
