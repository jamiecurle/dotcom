defmodule Jamie.Workers.PurgeUnconfirmedSubscribers do
  @moduledoc """
  Daily: deletes mailing list sign-ups whose confirmation link expired
  unused, so an address someone else typed in isn't kept.
  """
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    count = Jamie.MailingList.purge_unconfirmed()
    if count > 0, do: Logger.info("Oban: purged #{count} unconfirmed subscribers")
    :ok
  end
end
