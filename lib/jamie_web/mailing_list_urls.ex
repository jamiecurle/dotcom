defmodule JamieWeb.MailingListUrls do
  @moduledoc """
  The links the mailing list's emails carry, built in one place so the
  context and workers can make them without reaching into the web layer.
  """
  use JamieWeb, :verified_routes

  def url_for({:confirm, token}), do: url(~p"/subscribe/confirm/#{token}")
  def url_for({:manage, id}), do: url(~p"/subscribe/#{id}")
  # RFC 8058 one-click unsubscribe: mail providers POST here
  def url_for({:one_click, id}), do: url(~p"/subscribe/#{id}/unsubscribe")
  def url_for({:post, slug}), do: url(~p"/posts/#{slug}")
end
