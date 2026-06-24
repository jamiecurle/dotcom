defmodule Jamie.Opengraph.ImageTest do
  use ExUnit.Case, async: true

  alias Jamie.Opengraph.Image

  # The first eight bytes of every PNG file.
  @png_magic <<137, 80, 78, 71, 13, 10, 26, 10>>

  describe "create/3" do
    test "renders a non-empty PNG binary" do
      png = Image.create("A title", "A description", "/posts/a-title")

      assert is_binary(png)
      assert byte_size(png) > 0
      assert <<@png_magic, _rest::binary>> = png
    end

    test "renders regardless of title length (each font-size branch)" do
      # Real, wrappable titles that land in each of the three size buckets
      # (<= 30, 31..45, > 45 characters).
      short = "A short and sweet title"
      medium = "A medium length title that runs a fair bit longer here"
      long = "A long title that just keeps going on and on past forty five chars"

      for title <- [short, medium, long] do
        png = Image.create(title, "A description", "/posts/x")
        assert <<@png_magic, _rest::binary>> = png
      end
    end
  end
end
