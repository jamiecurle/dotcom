defmodule Jamie.AccountsMcpTokensTest do
  use Jamie.DataCase, async: true

  import Jamie.AccountsFixtures

  alias Jamie.Accounts
  alias Jamie.Accounts.{Scope, UserToken}
  alias Jamie.Repo

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user)}
  end

  test "a created token authenticates its user", %{user: user, scope: scope} do
    {encoded, %UserToken{context: "mcp"}} = Accounts.create_mcp_token(scope)

    assert {found, %UserToken{}} = Accounts.get_user_by_mcp_token(encoded)
    assert found.id == user.id
  end

  test "only the hash is stored", %{scope: scope} do
    {encoded, token} = Accounts.create_mcp_token(scope)
    {:ok, raw} = Base.url_decode64(encoded, padding: false)

    refute Repo.get!(UserToken, token.id).token == raw
  end

  test "garbage and unknown tokens are rejected" do
    assert nil == Accounts.get_user_by_mcp_token("not base64 !!")
    assert nil == Accounts.get_user_by_mcp_token(Base.url_encode64("nope", padding: false))
  end

  test "session tokens don't work as MCP tokens", %{user: user} do
    session_token = Accounts.generate_user_session_token(user)
    assert nil == Accounts.get_user_by_mcp_token(Base.url_encode64(session_token, padding: false))
  end

  test "expired tokens are rejected", %{scope: scope} do
    {encoded, token} = Accounts.create_mcp_token(scope)
    old = DateTime.add(DateTime.utc_now(:second), -(UserToken.mcp_validity_in_days() + 1), :day)
    Repo.update_all(from(t in UserToken, where: t.id == ^token.id), set: [inserted_at: old])

    assert nil == Accounts.get_user_by_mcp_token(encoded)
  end

  test "revoked tokens stop working", %{scope: scope} do
    {encoded, token} = Accounts.create_mcp_token(scope)
    :ok = Accounts.delete_mcp_token(scope, token.id)

    assert nil == Accounts.get_user_by_mcp_token(encoded)
  end

  test "a user can't revoke someone else's token", %{scope: scope} do
    {encoded, token} = Accounts.create_mcp_token(scope)
    other = Scope.for_user(user_fixture())
    :ok = Accounts.delete_mcp_token(other, token.id)

    assert {_, _} = Accounts.get_user_by_mcp_token(encoded)
    assert [] == Accounts.list_mcp_tokens(other)
    assert [%UserToken{}] = Accounts.list_mcp_tokens(scope)
  end
end
