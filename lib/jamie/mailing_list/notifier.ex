defmodule Jamie.MailingList.Notifier do
  @moduledoc """
  The mailing list's emails: confirming a sign-up, pointing someone already
  subscribed at their manage link, and the digests.

  Each has a `*_email` function that builds it without sending, which is
  what `/office/mailing-list/preview` shows, and a `deliver_*` that sends
  it. Every email is HTML (`Jamie.MailingList.EmailHTML`) with a plain-text
  twin, and every one ends with the manage link, which is also where
  unsubscribing happens.

  Confirmations go through Postmark's transactional stream, like the login
  emails; digests go through the broadcast stream.
  """
  import Swoosh.Email

  alias Jamie.Mailer
  alias Jamie.MailingList.EmailHTML

  ## Confirming a sign-up

  # A pending sign-up has no manage page yet (`MailingList.get_manageable/1`),
  # so this is the one email whose footer has no manage link: until they
  # confirm, there's nothing to change and nothing more will be sent.
  def confirmation_email(subscriber, confirm_url) do
    text = """
    Someone, hopefully you, asked to get new writing from jamiecurle.com by
    email. To confirm, open this link and press the button:

    #{confirm_url}

    The link works for 7 days. If this wasn't you, ignore this email.
    """

    new()
    |> to(subscriber.email)
    |> from(config()[:from])
    |> subject("Confirm your subscription")
    |> text_body(text <> text_footer(nil))
    |> html_body(EmailHTML.to_html(&EmailHTML.confirmation/1, confirm_url: confirm_url))
  end

  def deliver_confirmation(subscriber, confirm_url) do
    subscriber |> confirmation_email(confirm_url) |> deliver()
  end

  ## Signing up again

  def already_subscribed_email(subscriber, manage_url) do
    text = """
    Someone, hopefully you, tried to subscribe this address to
    jamiecurle.com, but it's already subscribed. To change what you get, or
    unsubscribe, go here:

    #{manage_url}
    """

    new()
    |> to(subscriber.email)
    |> from(config()[:from])
    |> subject("You're already subscribed")
    |> text_body(text <> text_footer(manage_url))
    |> html_body(EmailHTML.to_html(&EmailHTML.already_subscribed/1, manage_url: manage_url))
  end

  def deliver_already_subscribed(subscriber, manage_url) do
    subscriber |> already_subscribed_email(manage_url) |> deliver()
  end

  ## Digests

  @doc """
  A digest: the posts, each with its title, description and link, and the
  ways out. It goes through Postmark's broadcast stream with open and link
  tracking off, and carries the RFC 8058 headers that let Gmail, Yahoo and
  others offer a one-click unsubscribe.
  """
  def digest_email(subscriber, posts, frequency, url_fun) do
    manage = url_fun.({:manage, subscriber.id})
    one_click = url_fun.({:one_click, subscriber.id})

    posts =
      Enum.map(
        posts,
        &%{title: &1.title, description: &1.description, url: url_fun.({:post, &1.slug})}
      )

    new()
    |> to(subscriber.email)
    |> from(config()[:from])
    |> subject(digest_subject(posts, frequency))
    |> text_body(digest_text(posts) <> text_footer(manage))
    |> html_body(
      EmailHTML.to_html(&EmailHTML.digest/1,
        posts: posts,
        label: digest_label(posts, frequency),
        manage_url: manage
      )
    )
    |> header("List-Unsubscribe", "<#{one_click}>")
    |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    |> put_provider_option(:message_stream, config()[:broadcast_stream])
    |> put_provider_option(:track_opens, false)
    |> put_provider_option(:track_links, "None")
  end

  @doc "Sends a digest. Returns `{:ok, message_id}`."
  def deliver_digest(subscriber, posts, frequency, url_fun) do
    with {:ok, meta} <- subscriber |> digest_email(posts, frequency, url_fun) |> Mailer.deliver() do
      {:ok, meta[:id]}
    end
  end

  @doc """
  A digest sent to `address` to see how it lands in a real inbox, since
  the schedule sends nothing while the mailing list is switched off. It
  goes exactly the way a real digest does, through the broadcast stream
  (these are marketing emails), so it exercises that stream too; the
  subject says it's a test, and nothing is recorded. Its manage link
  belongs to nobody, so it leads to the not-found page.
  """
  def deliver_test_digest(address, posts, frequency, url_fun) do
    nobody = %{id: Ecto.UUID.generate(), email: address}
    email = digest_email(nobody, posts, frequency, url_fun)

    email
    |> subject("[Test] " <> email.subject)
    |> deliver()
  end

  defp digest_subject([post], _frequency), do: post.title

  defp digest_subject(posts, frequency),
    do: "#{length(posts)} new posts from jamiecurle.com, #{frequency_word(frequency)}"

  defp digest_label(_posts, frequency), do: "New writing, #{frequency_word(frequency)}"

  defp frequency_word(:daily), do: "today"
  defp frequency_word(:weekly), do: "this week"
  defp frequency_word(:monthly), do: "this month"

  defp digest_text(posts) do
    Enum.map_join(posts, "\n\n", fn post ->
      [post.title, post.description, post.url]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
    end) <> "\n"
  end

  ## Shared

  @reply "Feel free to hit reply – it'll land in my normal inbox. I'm always happy to have a conversation : )"

  # the plain-text twin of the HTML sign-off and footer
  defp text_footer(nil) do
    """

    #{@reply}

    --
    From jamiecurle.com. Nothing more will be sent unless you confirm.
    """
  end

  defp text_footer(manage_url) do
    """

    #{@reply}

    --
    From jamiecurle.com, because this address signed up for new writing.
    Manage subscription, or unsubscribe: #{manage_url}
    """
  end

  defp config, do: Application.get_env(:jamie, :mailing_list)

  defp deliver(email) do
    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
