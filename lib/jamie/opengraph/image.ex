defmodule Jamie.Opengraph.Image do
  @moduledoc """
  Generates open graph images for "things" with a title,
  description and maybe a url.

  https://jola.dev/posts/generating-og-images was a big help
  """

  alias Jamie.Blog
  alias Jamie.Storage.R2

  @doc """
  Given a post struct or an id of an post create
  and opengrah image and upload it into R2.
  """

  @spec for_post(Blog.Post.t() | integer) :: {:ok | :error, any()}
  def for_post(%Blog.Post{} = post) do
    create(post.title, post.description, "/posts/#{post.slug}")
    |> R2.put_file("opengraph/#{post.og_hash}.png")
  end

  def for_post(post) do
    Blog.get_post!(post)
    |> for_post()
  end

  @doc """
  Given a title, description, and a site-relative path (e.g. "/posts/slug"),
  render an open graph image in memory and return it as a PNG binary.
  """
  @spec create(String.t(), String.t(), String.t()) :: binary()
  def create(title, description, path) do
    # the path is shown as a full URL on the image
    url = "https://jamiecurle.com" <> path

    # the size of the title text needs to be controlled
    title_font_size =
      cond do
        String.length(title) > 45 -> 54
        String.length(title) > 30 -> 90
        true -> 108
      end

    # we need a font-file
    font_file = "priv/static/fonts/InterVariable.ttf"

    # make the title
    {:ok, title} =
      Image.Text.text(title,
        font: "Inter",
        font_file: font_file,
        font_size: title_font_size,
        font_weight: :normal,
        text_fill_color: [255, 255, 255],
        width: 865,
        letter_spacing: 0
      )

    # used in two places, store it on a variable
    title_height = Image.height(title)

    # open the bonsai
    {:ok, bonsai} = Image.open("priv/static/images/og_bonsai.png")

    # now place the description
    {:ok, description} =
      Image.Text.text(description,
        font: "Inter",
        font_file: font_file,
        font_size: 27,
        font_weight: 900,
        text_fill_color: [0, 206, 224],
        width: 865,
        letter_spacing: 0
      )

    {:ok, url} =
      Image.Text.text(url,
        font: "Inter",
        font_file: font_file,
        font_size: 16,
        font_weight: 600,
        text_fill_color: [255, 255, 255],
        width: 865,
        letter_spacing: 0
      )

    # finally, build the image
    Image.new!(1200, 630, color: [0, 206, 224])
    |> Image.compose!(title, x: 72, y: 72)
    |> Image.Draw.rect!(0, 72 + title_height + 72, 1200, 600, color: [62, 62, 62])
    # FUTURE YOU: CENTRALISE THE DESCRIPTION AND THE URL INSIDE THE RECTANGLE
    |> Image.compose!(description, x: 72, y: title_height + 196)
    |> Image.compose!(url, x: 72, y: title_height + 196 + Image.height(description) + 36)
    |> Image.compose!(bonsai, x: 980, y: title_height - 10)
    |> Image.write!(:memory, suffix: ".png")
  end
end
