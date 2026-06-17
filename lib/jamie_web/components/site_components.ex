defmodule JamieWeb.SiteComponents do
  @moduledoc """
  Site-wide components for the site
  """
  use Phoenix.Component

  @doc """
  A very crude home button
  """
  attr :current_path, :string, default: "/"

  def home(assigns) do
    ~H"""
    <%= if @current_path != "/" do %>
      <a href="/">
        &larr; HOME
      </a>
    <% end %>
    """
  end

  @months ~w(January February March April May June July August September October November December)

  @doc ~S"""
  Renders a date as "10th May 2026".

  If date is nil (perhaps not published yet) then returns "Draft"

  ## Examples
      <.pretty_date date={~D[2026-05-10]} />
  """
  attr :date, Date, default: nil

  def pretty_date(%{date: nil} = assigns) do
    ~H"""
    <time>Draft</time>
    """
  end

  def pretty_date(assigns) do
    assigns =
      assigns
      |> assign(:day, assigns.date.day)
      |> assign(:suffix, ordinal_suffix(assigns.date.day))
      |> assign(:month, Enum.at(@months, assigns.date.month - 1))
      |> assign(:year, assigns.date.year)

    ~H"""
    <time datetime={Date.to_iso8601(@date)}>{@day}{@suffix} {@month} {@year}</time>
    """
  end

  defp ordinal_suffix(day) when day in 11..13, do: "th"

  defp ordinal_suffix(day) do
    case rem(day, 10) do
      1 -> "st"
      2 -> "nd"
      3 -> "rd"
      _ -> "th"
    end
  end
end
