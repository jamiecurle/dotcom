defmodule Jamie.Support.FakeTurnstile do
  @moduledoc """
  Stands in for Jamie.Turnstile in tests: the token "pass" passes, anything
  else is rejected the way Cloudflare would.
  """

  def site_key, do: "test-site-key"

  def verify("pass"), do: :ok
  def verify(_token), do: {:error, {:rejected, ["invalid-input-response"]}}
end
