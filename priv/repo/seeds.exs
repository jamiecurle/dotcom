#
# posts
#
alias Jamie.Blog.Post

words = ~w(
  run jump swim fly climb crawl slide spin throw catch
  push pull lift drop kick punch grab release twist bend
  stretch fold cut break build destroy create write read draw
  paint sing dance play laugh cry whisper shout listen speak
  think dream sleep wake eat drink cook bake wash clean
  open close lock unlock start stop pause continue wait rush
  walk march skip hop dive sail drive ride carry drag
  hunt fish plant grow harvest dig pour mix stir shake
  mountain river ocean forest desert valley island volcano glacier cave
  dog cat horse elephant tiger eagle shark dolphin wolf bear
  apple mango peach grape lemon melon cherry plum pear fig
  table chair window door floor ceiling wall roof bridge tower
  sword shield arrow hammer axe spear bow dagger cannon lance
  cloud storm thunder lightning rain snow frost wind fog hail
  book map scroll letter journal poem song story legend myth
  king queen knight wizard dragon giant ghost witch elf dwarf
  fire water earth air shadow light darkness void spark flame
  ship boat cart wagon train plane rocket balloon raft canoe
  coin gem crystal pearl ruby sapphire emerald diamond gold silver
  clock mirror lantern compass telescope anchor bell drum flute horn
  city village castle dungeon temple market harbour farm mill forge
  friend enemy stranger merchant soldier farmer hunter healer thief scholar
  moon sun star comet nebula planet galaxy meteor aurora eclipse
  road path trail bridge gate tunnel stairs ladder fence wall
)

post_content = File.read!("priv/repo/post.md")
post2_content = File.read!("priv/repo/post2.md")

# Six posts per month going back `months_back` months from today.
# Evenly distributed by construction — we iterate per (month_offset, slot)
# rather than mapping a flat 1..N onto year/month arithmetic.
today = Date.utc_today()
months_back = 48
posts_per_month = 6

for month_offset <- 0..(months_back - 1),
    _slot <- 1..posts_per_month do
  # step back month_offset whole months from today (preserving day=1)
  month_anchor =
    Date.beginning_of_month(today)
    |> Date.shift(month: -month_offset)

  # for the current month, cap the day at today; otherwise span the whole month
  max_day =
    if month_offset == 0,
      do: today.day,
      else: Date.days_in_month(month_anchor)

  published_on = Date.new!(month_anchor.year, month_anchor.month, Enum.random(1..max_day))

  # 25% chance the post was edited a few days later
  edited_on =
    Enum.random([nil, nil, nil, Date.add(published_on, 3)])

  attrs = %{
    title: Enum.take_random(words, Enum.random(4..15)) |> Enum.join(" ") |> String.capitalize(),
    status: Enum.random([:published, :published, :published, :draft, :hidden]),
    description:
      Enum.take_random(words, Enum.random(20..45)) |> Enum.join(" ") |> String.capitalize(),
    markdown: Enum.random([post_content, post2_content]),
    published_on: published_on,
    edited_on: edited_on
  }

  # NOTE: Post.changeset/2 overwrites published_on with Date.utc_today() whenever
  # status is :published — we put_change AFTER to restore the seeded date.
  Post.changeset(%Post{}, attrs)
  |> Ecto.Changeset.put_change(:published_on, published_on)
  |> Jamie.Repo.insert(on_conflict: :nothing, conflict_target: :slug)
end

#
# now do users
#
alias Jamie.Accounts.User
d = "2026-04-01 00:00:00"

[%{email: "foo@bar.com", confirmed_at: d, inserted_at: d, updated_at: d}]
|> Enum.each(fn attrs ->
  User.seed_changeset(%User{}, attrs)
  |> Jamie.Repo.insert(on_conflict: :nothing, conflict_target: :email)
end)

#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
