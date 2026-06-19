defmodule Jamie.At.OpengraphImage do
  @moduledoc """
  Generates open graph images for "things" with a title,
  description and maybe a url.

  https://jola.dev/posts/generating-og-images was a big help
  """
  def create(title, description, _url \\ "") do
    # open the background
    {:ok, bg} = Image.open("priv/static/images/og-base.png")

    # make the title
    {:ok, title} =
      Image.Text.text(title,
        font: "Inter",
        font_size: 96,
        font_weight: :bold,
        text_fill_color: [255, 255, 255],
        width: 650
      )

    # and description
    {:ok, description} =
      Image.Text.text(description,
        font: "Inter",
        font_size: 32,
        font_weight: :normal,
        text_fill_color: [255, 255, 255],
        width: 650
      )

    # make the image
    Image.new!(1200, 630, color: [10, 10, 10])
    |> Image.compose!(bg, x: 0, y: 0)
    |> Image.compose!(title, x: 550, y: 48)
    |> Image.compose!(description, x: 550, y: 48 - Image.height(title))
  end
end
