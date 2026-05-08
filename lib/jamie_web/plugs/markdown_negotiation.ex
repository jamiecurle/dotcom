defmodule JamieWeb.Plugs.MarkdownNegotiation do
  @moduledoc """
  Implements the [Markdown for Agents](https://developers.cloudflare.com/fundamentals/reference/markdown-for-agents/)
  content-negotiation skill. When a GET request prefers `text/markdown`
  in its `Accept` header, returns a markdown rendering of the resource
  with `Content-Type: text/markdown; charset=utf-8` and an
  `x-markdown-tokens` header. Otherwise the conn is left unchanged so
  the normal HTML pipeline handles the request.
  """

  @behaviour Plug

  import Plug.Conn

  alias JamieWeb.MarkdownRenderer

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    cond do
      not prefers_markdown?(conn) ->
        conn

      conn.method == "GET" ->
        case MarkdownRenderer.render(conn.path_info) do
          {:ok, body} -> respond_markdown(conn, body)
          :passthrough -> downgrade_to_html(conn)
        end

      true ->
        downgrade_to_html(conn)
    end
  end

  # The route does not have a markdown rendering. Rewrite the Accept
  # header so the rest of the browser pipeline (`plug :accepts, ["html"]`,
  # LiveView, controllers) treats this as a regular HTML request rather
  # than 406-ing on the agent's `Accept: text/markdown`.
  defp downgrade_to_html(conn) do
    %{conn | req_headers: List.keystore(conn.req_headers, "accept", 0, {"accept", "text/html"})}
  end

  defp respond_markdown(conn, body) do
    conn
    |> put_resp_content_type("text/markdown", "utf-8")
    |> put_resp_header("x-markdown-tokens", token_count(body))
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
    |> halt()
  end

  # Rough heuristic: ~4 bytes per token. Cheap, no extra deps, and the
  # spec only asks for a count "if available".
  defp token_count(body) do
    body |> byte_size() |> div(4) |> Integer.to_string()
  end

  @doc false
  def prefers_markdown?(conn) do
    conn
    |> get_req_header("accept")
    |> List.first()
    |> parse_accept()
    |> markdown_preferred?()
  end

  defp parse_accept(nil), do: []
  defp parse_accept(""), do: []

  defp parse_accept(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_entry/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_entry(entry) do
    case String.split(entry, ";") do
      [type | params] ->
        type = type |> String.trim() |> String.downcase()
        if type == "", do: nil, else: {type, q_value(params)}

      _ ->
        nil
    end
  end

  defp q_value(params) do
    Enum.find_value(params, 1.0, &parse_q/1)
  end

  defp parse_q(param) do
    case param |> String.trim() |> String.downcase() |> String.split("=") do
      ["q", v] -> parse_float(v)
      _ -> nil
    end
  end

  defp parse_float(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> nil
    end
  end

  # Markdown wins iff it appears explicitly AND its q-value is strictly
  # greater than html's (or html is absent). Wildcards (`*/*`) do not
  # trigger markdown.
  defp markdown_preferred?(entries) do
    md = Enum.find_value(entries, fn {t, q} -> if t == "text/markdown", do: q end)
    html = Enum.find_value(entries, fn {t, q} -> if t == "text/html", do: q end)

    cond do
      is_nil(md) -> false
      is_nil(html) -> true
      md > html -> true
      true -> false
    end
  end
end
