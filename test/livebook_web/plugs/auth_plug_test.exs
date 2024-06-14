defmodule LivebookWeb.AuthPlugTest do
  # Not async, because we alter global config (auth mode)
  use LivebookWeb.ConnCase, async: false

  setup context do
    authentication =
      cond do
        context[:token] -> :token
        password = context[:password] -> {:password, password}
        true -> :disabled
      end

    unless authentication == :disabled do
      Application.put_env(:livebook, :authentication, authentication)

      on_exit(fn ->
        Application.put_env(:livebook, :authentication, :disabled)
      end)
    end

    :ok
  end

  describe "token authentication" do
    test "skips authentication when no token is configured", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert conn.status == 200
      assert conn.resp_body =~ "New notebook"
    end

    @tag :token
    test "redirects to /authenticate if not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/authenticate"
    end

    @tag :token
    test "redirects to the same path when valid token is provided in query params", %{conn: conn} do
      conn = get(conn, ~p"/?token=#{auth_token()}")

      assert redirected_to(conn) == ~p"/"
    end

    @tag :token
    test "redirects to /authenticate when invalid token is provided in query params",
         %{conn: conn} do
      conn = get(conn, ~p"/?token=invalid")
      assert redirected_to(conn) == ~p"/authenticate"
    end

    @tag :token
    test "persists authentication across requests", %{conn: conn} do
      conn = get(conn, ~p"/?token=#{auth_token()}")
      assert get_session(conn, "80:token")

      conn = get(conn, ~p"/")
      assert conn.status == 200
      assert conn.resp_body =~ "New notebook"
    end

    @tag :token
    test "redirects to referer on valid authentication", %{conn: conn} do
      referer = "/import?url=example.com"

      conn = get(conn, referer)
      assert redirected_to(conn) == ~p"/authenticate"

      conn = post(conn, ~p"/authenticate", token: auth_token())
      assert redirected_to(conn) == referer
    end

    @tag :token
    test "redirects back to /authenticate on invalid token", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?token=invalid_token")
      assert html_response(conn, 200) =~ "Authentication required"

      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/authenticate"
    end

    @tag :token
    test "persists authentication across requests (via /authenticate)", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?token=#{auth_token()}")
      assert get_session(conn, "80:token")

      conn = get(conn, ~p"/")
      assert conn.status == 200
      assert conn.resp_body =~ "New notebook"

      conn = get(conn, ~p"/authenticate")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "password authentication" do
    test "redirects to '/' if no authentication is required", %{conn: conn} do
      conn = get(conn, ~p"/authenticate")
      assert redirected_to(conn) == ~p"/"
    end

    @tag password: "grumpycat"
    test "does not crash when given a token", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?token=grumpycat")
      assert html_response(conn, 200) =~ "token is invalid"
    end

    @tag password: "grumpycat"
    test "redirects to /authenticate if not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/authenticate"
    end

    @tag password: "grumpycat"
    test "redirects to '/' on valid authentication", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?password=grumpycat")
      assert redirected_to(conn) == ~p"/"

      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "New notebook"
    end

    @tag password: "grumpycat"
    test "redirects to referer on valid authentication", %{conn: conn} do
      referer = "/import?url=example.com"

      conn = get(conn, referer)
      assert redirected_to(conn) == ~p"/authenticate"

      conn = post(conn, ~p"/authenticate", password: "grumpycat")
      assert redirected_to(conn) == referer
    end

    @tag password: "grumpycat"
    test "redirects back to /authenticate on invalid password", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?password=invalid_password")
      assert html_response(conn, 200) =~ "Authentication required"

      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/authenticate"
    end

    @tag password: "grumpycat"
    test "persists authentication across requests", %{conn: conn} do
      conn = post(conn, ~p"/authenticate?password=grumpycat")
      assert get_session(conn, "80:password")

      conn = get(conn, ~p"/")
      assert conn.status == 200
      assert conn.resp_body =~ "New notebook"

      conn = get(conn, ~p"/authenticate")
      assert redirected_to(conn) == ~p"/"
    end
  end

  defp auth_token() do
    %{mode: :token, secret: token} = Livebook.Config.authentication()
    token
  end
end
