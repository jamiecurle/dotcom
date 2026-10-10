defmodule Jamie.Workers.DigestDeliver do
  @moduledoc """
  Sends one subscriber's digest for one period. Safe to run twice: see
  `Jamie.MailingList.Digests.deliver/4`.
  """
  use Oban.Worker,
    queue: :mail,
    max_attempts: 5,
    unique: [keys: [:subscriber_id, :period], period: :infinity, states: :incomplete]

  require Logger

  alias Jamie.MailingList.Digests

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subscriber_id" => id, "period" => period} = args}) do
    frequency = String.to_existing_atom(args["frequency"])

    case Digests.deliver(id, period, frequency, &JamieWeb.MailingListUrls.url_for/1) do
      {:ok, _outcome} ->
        :ok

      {:error, reason} = error ->
        Logger.error("Oban: digest #{period} failed: #{inspect(reason)}")
        error
    end
  end
end
