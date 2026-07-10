defmodule Jamie.Support.FakeR2Test do
  # async: true is safe because the store lives in the process dictionary,
  # so each test process gets its own isolated "bucket".
  use ExUnit.Case, async: true

  alias Jamie.Support.FakeR2

  describe "put_file/2 and list_files/0" do
    test "a put file shows up in the listing" do
      assert {:ok, %{contents: []}} = unwrap(FakeR2.list_files())

      FakeR2.put_file("png-bytes", "opengraph/abc.png")

      assert {:ok, %{contents: [%{key: "opengraph/abc.png"}]}} =
               unwrap(FakeR2.list_files())
    end

    test "put returns an ExAws-shaped success tuple" do
      assert {:ok, %{status_code: 200}} = FakeR2.put_file("bytes", "a.png")
    end
  end

  describe "get_file/1" do
    test "returns the stashed contents" do
      FakeR2.put_file("the-bytes", "a.png")
      assert {:ok, %{body: "the-bytes"}} = FakeR2.get_file("a.png")
    end

    test "returns :not_found for an unknown key" do
      assert {:error, :not_found} = FakeR2.get_file("missing.png")
    end
  end

  # list_files/0 wraps its result in the ExAws {:ok, %{body: ...}} envelope;
  # this pulls the body out so the assertions above stay readable.
  defp unwrap({:ok, %{body: body}}), do: {:ok, body}
end
