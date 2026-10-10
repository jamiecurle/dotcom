defmodule Jamie.Workers.DigestSchedule do
  @moduledoc """
  Run by cron at 8am London time for each frequency (see config.exs): queues
  a `DigestDeliver` job per subscriber who's due. Does nothing while the
  mailing list is switched off.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Jamie.MailingList
  alias Jamie.MailingList.Digests
  alias Jamie.Workers.DigestDeliver

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"frequency" => frequency}}) do
    if MailingList.enabled?() do
      frequency = String.to_existing_atom(frequency)
      period = Digests.period(frequency, Digests.today())

      frequency
      |> Digests.due()
      |> Enum.map(
        &DigestDeliver.new(%{"subscriber_id" => &1, "period" => period, "frequency" => frequency})
      )
      |> Oban.insert_all()
    end

    :ok
  end
end
