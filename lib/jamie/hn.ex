defmodule Jamie.HN do
  @moduledoc """
  Scrapes a user's HN favorites page and hydrates each item via the
  Firebase API.
  """

  @favorites_url "https://news.ycombinator.com/favorites?id="
  @item_url "https://hacker-news.firebaseio.com/v0/item/"

  def favorites(username) do
    with {:ok, %{status: 200, body: html}} <-
           Req.get(@favorites_url <> username,
             headers: [{"user-agent", "jamiecurle.com favorites sync (jamie@curle.io)"}]
           ) do
      html
      |> parse_ids()

      # |> Enum.map(&fetch_item/1)
      # |> Enum.reject(&is_nil/1)
    end
  end

  defp parse_ids(html) do
    {:ok, doc} = Floki.parse_document(html)

    doc
    |> Floki.find("tr.athing")
    |> Enum.map(&Floki.attribute(&1, "id"))
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
  end

  defp fetch_item(id) do
    Process.sleep(500)

    case Req.get(@item_url <> "#{id}.json",
           headers: [{"user-agent", "jamiecurle.com favorites sync (jamie@curle.io)"}]
         ) do
      {:ok, %{status: 200, body: item}} -> item
      _ -> nil
    end
  end
end
