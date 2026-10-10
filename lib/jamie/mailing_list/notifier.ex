defmodule Jamie.MailingList.Notifier do
  @moduledoc """
  The mailing list's own emails, the ones that aren't digests: confirming
  a sign-up, and pointing someone already subscribed at their manage link.
  These go through Postmark's transactional stream, like the login emails;
  digests will go through the broadcast stream.
  """
  import Swoosh.Email

  alias Jamie.Mailer

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

  @doc """
  A digest: the posts, each with its title, description and link, and the
  ways out. Goes through Postmark's broadcast stream with open and link
  tracking off, and carries the RFC 8058 headers that let Gmail, Yahoo and
  others offer a one-click unsubscribe. Returns `{:ok, message_id}`.
  """
  def deliver_digest(subscriber, posts, frequency, url_fun) do
    manage = url_fun.({:manage, subscriber.id})
    one_click = url_fun.({:one_click, subscriber.id})

    posts =
      Enum.map(
        posts,
        &%{title: &1.title, description: &1.description, url: url_fun.({:post, &1.slug})}
      )

    email =
      new()
      |> to(subscriber.email)
      |> from(config()[:from])
      |> subject(digest_subject(posts, frequency))
      |> text_body(digest_text(posts, manage))
      |> html_body(digest_html(posts, manage))
      |> header("List-Unsubscribe", "<#{one_click}>")
      |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
      |> put_provider_option(:message_stream, config()[:broadcast_stream])
      |> put_provider_option(:track_opens, false)
      |> put_provider_option(:track_links, "None")

    with {:ok, meta} <- Mailer.deliver(email) do
      {:ok, meta[:id]}
    end
  end

  defp digest_subject([post], _frequency), do: post.title

  defp digest_subject(posts, frequency),
    do: "#{length(posts)} new posts from jamiecurle.com, #{frequency_word(frequency)}"

  defp frequency_word(:daily), do: "today"
  defp frequency_word(:weekly), do: "this week"
  defp frequency_word(:monthly), do: "this month"

  defp digest_text(posts, manage) do
    items =
      Enum.map_join(posts, "\n\n", fn post ->
        "#{post.title}\n#{post.description}\n#{post.url}"
      end)

    """
    #{items}

    --
    Change what you get, or unsubscribe: #{manage}
    """
  end

  # Deliberately plain for now; HEEM-350 gives it the site's look.
  defp digest_html(posts, manage) do
    items =
      Enum.map_join(posts, "\n", fn post ->
        """
        <h2 style="font-size:20px;margin:24px 0 4px"><a href="#{escape(post.url)}" style="color:#1e1e1e">#{escape(post.title)}</a></h2>
        <p style="margin:0;color:#484e4e">#{escape(post.description)}</p>
        """
      end)

    """
    <div style="font-family:Helvetica,Arial,sans-serif;max-width:560px;margin:0 auto;color:#1e1e1e">
    #{items}
    <p style="margin-top:40px;font-size:13px;color:#797f7f"><a href="#{escape(manage)}" style="color:#797f7f">Change what you get, or unsubscribe</a></p>
    </div>
    """
  end

  defp escape(nil), do: ""

  defp escape(text),
    do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp config, do: Application.get_env(:jamie, :mailing_list)

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(config()[:from])
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
