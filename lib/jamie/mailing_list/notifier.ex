defmodule Jamie.MailingList.Notifier do
  @moduledoc """
  The mailing list's own emails, the ones that aren't digests: confirming
  a sign-up, and pointing someone already subscribed at their manage link.
  These go through Postmark's transactional stream, like the login emails;
  digests will go through the broadcast stream.
  """
  import Swoosh.Email

  alias Jamie.Mailer

  @from {"Jamie Curle", "jamie@curle.io"}

  def deliver_confirmation(subscriber, confirm_url) do
    deliver(subscriber.email, "Confirm your subscription", """
    Hello,

    Someone, hopefully you, asked to get new writing from jamiecurle.com by
    email. To confirm, open this link and press the button:

    #{confirm_url}

    The link works for 7 days. If this wasn't you, ignore this email and
    nothing more will be sent.

    Jamie
    """)
  end

  def deliver_already_subscribed(subscriber, manage_url) do
    deliver(subscriber.email, "You're already subscribed", """
    Hello,

    Someone, hopefully you, tried to subscribe this address to
    jamiecurle.com, but it's already subscribed. To change what you get, or
    unsubscribe, go here:

    #{manage_url}

    Jamie
    """)
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
