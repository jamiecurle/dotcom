defmodule Jamie.Workers.MailingListHousekeeping do
  @moduledoc """
  Daily tidying for the mailing list, so nothing is kept longer than it's
  needed:

    * sign-ups whose confirmation link expired unused are deleted, so an
      address someone else typed in isn't kept
    * Postmark events older than #{Jamie.MailingList.email_event_retention_days()} days are deleted
  """
  use Oban.Worker, queue: :default

  require Logger

  alias Jamie.MailingList

  @impl Oban.Worker
  def perform(_job) do
    subscribers = MailingList.purge_unconfirmed()
    events = MailingList.purge_old_email_events()

    if subscribers + events > 0 do
      Logger.info("Oban: purged #{subscribers} unconfirmed subscribers, #{events} email events")
    end

    :ok
  end
end
