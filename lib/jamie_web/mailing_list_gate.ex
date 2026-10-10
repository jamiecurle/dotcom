defmodule JamieWeb.MailingListGate do
  @moduledoc """
  Keeps the mailing list's pages hidden until it's switched on, by answering
  404 to anyone but me. Goes after `:mount_current_scope` in a live_session's
  on_mount, since it needs to know who's asking.
  """

  alias Jamie.MailingList

  def on_mount(:default, _params, _session, socket) do
    if MailingList.visible?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      raise JamieWeb.NotFoundError
    end
  end
end
