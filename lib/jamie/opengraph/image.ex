defmodule Jamie.Opengraph.Image do
  @moduledoc """
  Generates open graph images for "things" with a title,
  description and maybe a url.

  https://jola.dev/posts/generating-og-images was a big help
  """

  alias Jamie.Content
  alias Jamie.Service.R2

  @doc """
  Given a post struct or an id of an post create
  and opengrah image and upload it into R2.
  """

  @spec for_post(Content.Post.t() | integer) :: {:ok | :error, any()}
  def for_post(%Content.Post{} = post) do
    create(post.title, post.description, "/posts/#{post.slug}")
    |> R2.put_file("opengraph/#{post.og_hash}.png")
  end

  def for_post(post) do
    Content.get_post!(post)
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

    # make the title
    {:ok, title} =
      Image.Text.text(title, text_opts(title_font_size, :normal, [255, 255, 255]))

    # used in two places, store it on a variable
    title_height = Image.height(title)

    # open the bonsai
    {:ok, bonsai} = Image.open(priv_path("images/og_bonsai.png"))

    # now place the description
    {:ok, description} =
      Image.Text.text(description, text_opts(27, 900, [0, 206, 224]))

    {:ok, url} =
      Image.Text.text(url, text_opts(16, 600, [255, 255, 255]))

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

  # Text options shared by every label on the image. Only the size, weight,
  # and colour change per call; everything else (font, width, spacing) is fixed.
  defp text_opts(font_size, font_weight, fill_color) do
    [
      font_size: font_size,
      font_weight: font_weight,
      text_fill_color: fill_color,
      width: 865,
      letter_spacing: 0
    ] ++ font_opts()
  end

  # Inter is bundled with the app and is the canonical OG font. On Linux
  # (production and CI) we point libvips straight at the .ttf via :font_file.
  # That option isn't supported on macOS — it only emits a noisy fontconfig
  # error — so for local previews we omit it and let the system resolve "Inter"
  # by name, falling back to a default face if it isn't installed.
  defp font_opts do
    case :os.type() do
      {:unix, :darwin} ->
        [font: "Inter"]

      _ ->
        [font: "Inter", font_file: priv_path("fonts/InterVariable.ttf")]
    end
  end

  # Resolve a path inside priv/static. We must go through Application.app_dir/2
  # rather than a bare "priv/..." relative path: in a release the working
  # directory is not the project root, so a relative path fails with :enoent
  # even though the file is bundled. app_dir points at the priv dir inside the
  # release (and at the project priv dir in dev), so it works everywhere.
  defp priv_path(relative) do
    Application.app_dir(:jamie, Path.join("priv/static", relative))
  end
end
