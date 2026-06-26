defmodule Jamie.Analytics.Pageview do
  @moduledoc """
  A single recorded pageview. Append-only: we never update or delete
  individual rows, so there is no `updated_at`.

  Privacy note: we deliberately store no IP address and no cookie. The
  `visitor_hash` is a one-way hash of IP + user-agent + a salt that
  rotates daily (see `Jamie.Analytics.visitor_hash/2`), which lets us
  count unique visitors within a day without holding any personal data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @device_types ~w(desktop mobile tablet bot other)

  schema "pageviews" do
    field :path, :string
    field :referrer_host, :string
    field :browser, :string
    field :os, :string
    field :device_type, :string
    field :country, :string
    field :visitor_hash, :string

    # Only an insertion timestamp — these rows are immutable.
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [
      :path,
      :referrer_host,
      :browser,
      :os,
      :device_type,
      :country,
      :visitor_hash
    ])
    |> validate_required([:path, :visitor_hash])
    |> validate_inclusion(:device_type, @device_types)
    |> validate_length(:path, max: 2048)
  end
end
