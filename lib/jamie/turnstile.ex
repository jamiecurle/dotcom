defmodule Jamie.Turnstile do
  @moduledoc """
  Cloudflare Turnstile: the bot check on public forms. The widget in the
  page hands the browser a token, the form posts it, and this asks
  Cloudflare whether it's genuine.

  Called through the `:turnstile` service, so tests can swap in a fake.
  Without real keys in the environment it uses Cloudflare's test keys,
  which always pass. Fine while the mailing list is gated, not after.
  """

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  @doc "The public key the widget in the page needs."
  def site_key, do: Application.get_env(:jamie, :turnstile)[:site_key]

  @doc """
  Checks a token from the widget with Cloudflare. The visitor's IP isn't
  sent; Cloudflare doesn't need it to verify.
  """
  def verify(token) when is_binary(token) and token != "" do
    form = [secret: Application.get_env(:jamie, :turnstile)[:secret_key], response: token]

    case Req.post(@verify_url, form: form, retry: false) do
      {:ok, %{status: 200, body: %{"success" => true}}} -> :ok
      {:ok, %{body: %{"error-codes" => codes}}} -> {:error, {:rejected, codes}}
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify(_token), do: {:error, :missing}
end
