defmodule JamieWeb.AgentSkillsTest do
  use JamieWeb.ConnCase, async: true

  @index_path "/.well-known/agent-skills/index.json"

  describe "GET /.well-known/agent-skills/index.json" do
    test "is served as JSON", %{conn: conn} do
      conn = get(conn, @index_path)
      assert response_content_type(conn, :json) =~ "application/json"
    end

    test "matches the discovery RFC v0.2.0 schema", %{conn: conn} do
      conn = get(conn, @index_path)
      index = conn |> response(200) |> Jason.decode!()

      assert index["$schema"] == "https://schemas.agentskills.io/discovery/0.2.0/schema.json"
      assert is_list(index["skills"])
      assert index["skills"] != []

      for skill <- index["skills"] do
        assert is_binary(skill["name"])
        assert skill["name"] =~ ~r/\A[a-z0-9-]{1,64}\z/
        assert skill["type"] in ["skill-md", "archive"]
        assert is_binary(skill["description"])
        assert String.length(skill["description"]) <= 1024
        assert is_binary(skill["url"])
        assert skill["digest"] =~ ~r/\Asha256:[0-9a-f]{64}\z/
      end
    end

    test "expected skills are present", %{conn: conn} do
      conn = get(conn, @index_path)
      index = conn |> response(200) |> Jason.decode!()

      names = Enum.map(index["skills"], & &1["name"])
      assert "read-blog-content" in names
      assert "contact" in names
    end
  end

  describe "skill artifacts" do
    test "every skill url is reachable and matches its digest", %{conn: conn} do
      index =
        conn
        |> get(@index_path)
        |> response(200)
        |> Jason.decode!()

      for skill <- index["skills"] do
        artifact_conn = get(build_conn(), skill["url"])
        body = response(artifact_conn, 200)

        "sha256:" <> expected = skill["digest"]

        actual = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

        assert actual == expected,
               "digest mismatch for #{skill["name"]} at #{skill["url"]}"
      end
    end

    test "skill-md artifacts include yaml frontmatter with name and description", %{conn: conn} do
      index =
        conn
        |> get(@index_path)
        |> response(200)
        |> Jason.decode!()

      for skill <- Enum.filter(index["skills"], &(&1["type"] == "skill-md")) do
        body = build_conn() |> get(skill["url"]) |> response(200)

        assert String.starts_with?(body, "---\n"),
               "#{skill["name"]} is missing YAML frontmatter"

        assert body =~ ~r/^name:\s*#{Regex.escape(skill["name"])}\s*$/m
        assert body =~ ~r/^description:\s*\S/m
      end
    end
  end
end
