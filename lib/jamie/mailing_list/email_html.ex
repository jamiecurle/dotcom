defmodule Jamie.MailingList.EmailHTML do
  @moduledoc """
  The HTML half of the mailing list's emails, set like the site: the name
  as type, tracked upper labels on 2px rules, big tight titles on hairlines,
  a plain black button.

  Email clients ignore stylesheets, web fonts and most of modern CSS, so
  everything is inline, laid out in a 600px table, in the system's own
  Helvetica. Nothing remote is loaded: no fonts, images or tracking pixels.
  The colours are the hex ones from light.css, since `oklch` doesn't reach
  most inboxes.
  """
  use Phoenix.Component

  alias Phoenix.HTML.Safe

  @ink "#1e1e1e"
  @body "#484e4e"
  @quiet "#797f7f"
  @rule "#e8e8e8"
  @paper "#ffffff"
  @wash "#f5f4f4"

  @font "'Helvetica Neue', Helvetica, Arial, sans-serif"

  @doc "Renders a component to a string of HTML."
  def to_html(component, assigns) do
    assigns
    |> Map.new()
    |> component.()
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  ## The emails

  attr :posts, :list, required: true, doc: "maps of title, description and url"
  attr :label, :string, required: true
  attr :manage_url, :string, required: true

  def digest(assigns) do
    ~H"""
    <.layout preheader={preheader(@posts)} manage_url={@manage_url}>
      <.label text={@label} />
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <%!-- hairlines between posts; the footer's rule closes the last one --%>
        <tr :for={{post, i} <- Enum.with_index(@posts)}>
          <td style={"padding:24px 0;#{if i > 0, do: "border-top:1px solid #{rule()}"}"}>
            <a
              href={post.url}
              style={"font-family:#{font()};font-size:28px;line-height:32px;font-weight:700;letter-spacing:-1px;color:#{ink()};text-decoration:none"}
            >
              {post.title}
            </a>
            <p
              :if={post.description}
              style={"margin:8px 0 0;font-family:#{font()};font-size:16px;line-height:24px;color:#{body()}"}
            >
              {post.description}
            </p>
            <p style={"margin:12px 0 0;font-family:#{font()};font-size:13px;line-height:18px;font-weight:600;text-transform:uppercase;letter-spacing:0.05em"}>
              <a href={post.url} style={"color:#{ink()}"}>Read it</a>
            </p>
          </td>
        </tr>
      </table>
    </.layout>
    """
  end

  attr :confirm_url, :string, required: true

  def confirmation(assigns) do
    ~H"""
    <.layout preheader="One click to start getting new writing by email.">
      <.label text="Confirm your subscription" />
      <.para>
        Someone, hopefully you, asked to get new writing from jamiecurle.com by email.
        To confirm, press the button below, then once more on the page it opens.
      </.para>
      <.button href={@confirm_url} text="Confirm" />
      <.para quiet>
        The link works for 7 days. If this wasn't you, ignore this email.
      </.para>
    </.layout>
    """
  end

  attr :manage_url, :string, required: true

  def already_subscribed(assigns) do
    ~H"""
    <.layout preheader="This address already gets new writing by email." manage_url={@manage_url}>
      <.label text="You're already subscribed" />
      <.para>
        Someone, hopefully you, tried to subscribe this address to jamiecurle.com,
        but it's already subscribed. To change what you get, or unsubscribe:
      </.para>
      <.button href={@manage_url} text="Your subscription" />
    </.layout>
    """
  end

  ## The pieces

  attr :preheader, :string, required: true
  attr :manage_url, :string, default: nil, doc: "none before they've confirmed"
  slot :inner_block, required: true

  # the frame every email shares: the name, the content, the ways out
  defp layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="light" />
        <meta name="supported-color-schemes" content="light" />
      </head>
      <body style={"margin:0;padding:0;background:#{wash()}"}>
        <%!-- the line inboxes show after the subject, hidden in the email itself --%>
        <div style="display:none;max-height:0;overflow:hidden;opacity:0">{@preheader}</div>
        <table
          role="presentation"
          width="100%"
          cellpadding="0"
          cellspacing="0"
          border="0"
          style={"background:#{wash()}"}
        >
          <tr>
            <td align="center" style="padding:24px 12px">
              <table
                role="presentation"
                width="600"
                cellpadding="0"
                cellspacing="0"
                border="0"
                style={"width:100%;max-width:600px;background:#{paper()}"}
              >
                <tr>
                  <td style="padding:32px 32px 0">
                    <a
                      href="https://jamiecurle.com"
                      style={"font-family:#{font()};font-size:18px;line-height:18px;font-weight:700;letter-spacing:-0.5px;color:#{ink()};text-decoration:none"}
                    >
                      Jamie Curle
                    </a>
                  </td>
                </tr>
                <tr>
                  <td style="padding:40px 32px 8px">
                    {render_slot(@inner_block)}
                  </td>
                </tr>
                <%!-- a sign-off: replies go to a real inbox, read by a person --%>
                <tr>
                  <td style="padding:8px 32px 0">
                    <.para>
                      Feel free to hit reply – it'll land in my normal inbox. I'm always happy to have a conversation : )
                    </.para>
                  </td>
                </tr>
                <tr>
                  <td style="padding:24px 32px 32px">
                    <.footer manage_url={@manage_url} />
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  attr :manage_url, :string, default: nil

  defp footer(assigns) do
    ~H"""
    <p style={"margin:0;padding-top:12px;border-top:2px solid #{ink()};font-family:#{font()};font-size:13px;line-height:20px;color:#{quiet()}"}>
      <%= if @manage_url do %>
        From jamiecurle.com, because this address signed up for new writing.<br />
        <a href={@manage_url} style={"color:#{quiet()}"}>Manage subscription</a>
        &nbsp;·&nbsp; <a href={@manage_url} style={"color:#{quiet()}"}>Unsubscribe</a>
      <% else %>
        From jamiecurle.com. Nothing more will be sent unless you confirm.
      <% end %>
    </p>
    """
  end

  attr :text, :string, required: true

  # a tracked upper label on a 2px rule, like the site's section heads
  defp label(assigns) do
    ~H"""
    <p style={"margin:0 0 8px;padding-bottom:6px;border-bottom:2px solid #{ink()};font-family:#{font()};font-size:13px;line-height:18px;font-weight:600;text-transform:uppercase;letter-spacing:0.05em;color:#{ink()}"}>
      {@text}
    </p>
    """
  end

  attr :quiet, :boolean, default: false
  slot :inner_block, required: true

  defp para(assigns) do
    ~H"""
    <p style={"margin:16px 0;font-family:#{font()};font-size:#{if @quiet, do: 14, else: 17}px;line-height:#{if @quiet, do: 21, else: 26}px;color:#{if @quiet, do: quiet(), else: body()}"}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :href, :string, required: true
  attr :text, :string, required: true

  defp button(assigns) do
    ~H"""
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:24px 0">
      <tr>
        <td style={"background:#{ink()}"}>
          <a
            href={@href}
            style={"display:inline-block;padding:14px 28px;font-family:#{font()};font-size:15px;line-height:18px;font-weight:700;text-transform:uppercase;letter-spacing:0.05em;color:#{paper()};text-decoration:none"}
          >
            {@text}
          </a>
        </td>
      </tr>
    </table>
    """
  end

  # the first titles, so an inbox shows what's inside before it's opened
  defp preheader(posts), do: Enum.map_join(posts, " · ", & &1.title)

  defp ink, do: @ink
  defp body, do: @body
  defp quiet, do: @quiet
  defp rule, do: @rule
  defp paper, do: @paper
  defp wash, do: @wash
  defp font, do: @font
end
