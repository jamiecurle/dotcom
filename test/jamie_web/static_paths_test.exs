defmodule JamieWeb.StaticPathsTest do
  use ExUnit.Case, async: true

  describe "static_prefixes/0" do
    test "covers the digested name of every root-level static file" do
      # In production phx.digest renames root files to `<name>-<hash>.<ext>`, and
      # `~p` resolves to that digested name. Plug.Static's `:only` matches a segment
      # exactly, so only `:only_matching` (prefixes) can serve the digested form.
      # A root file with no covering prefix silently 404s in prod but not in dev,
      # which is exactly how the favicons and web manifest broke.
      root_files =
        Enum.filter(JamieWeb.static_paths(), fn path ->
          String.contains?(path, ".") and not String.starts_with?(path, ".")
        end)

      # Guard the guard: if static_paths/0 is ever restructured so nothing matches
      # here, the loop below would vacuously pass and stop protecting anything.
      assert root_files != []

      for path <- root_files do
        assert Enum.any?(JamieWeb.static_prefixes(), &String.starts_with?(path, &1)),
               "#{path} is listed in static_paths/0 but no prefix in static_prefixes/0 " <>
                 "covers its digested name, so it will 404 in production"
      end
    end

    test "every prefix belongs to a file that is actually served" do
      # Keeps the list from accumulating prefixes for files that no longer exist,
      # which would widen Plug.Static's reach for no reason.
      for prefix <- JamieWeb.static_prefixes() do
        assert Enum.any?(JamieWeb.static_paths(), &String.starts_with?(&1, prefix)),
               "static_prefixes/0 lists #{prefix}, but no path in static_paths/0 starts " <>
                 "with it - remove the stale prefix"
      end
    end
  end
end
