defmodule AdminAPI.V1.TokenControllerTest do
  use AdminAPI.ConnCase, async: true
  alias EWalletDB.{Repo, Token, Mint}

  describe "/token.all" do
    test "returns a list of tokens and pagination data" do
      response = user_request("/token.all")

      # Asserts return data
      assert response["success"]
      assert response["data"]["object"] == "list"
      assert is_list(response["data"]["data"])

      # Asserts pagination data
      pagination = response["data"]["pagination"]
      assert is_integer(pagination["per_page"])
      assert is_integer(pagination["current_page"])
      assert is_boolean(pagination["is_last_page"])
      assert is_boolean(pagination["is_first_page"])
    end

    test "returns a list of tokens according to search_term, sort_by and sort_direction" do
      insert(:token, %{symbol: "XYZ1"})
      insert(:token, %{symbol: "XYZ3"})
      insert(:token, %{symbol: "XYZ2"})
      insert(:token, %{symbol: "ZZZ1"})

      attrs = %{
        # Search is case-insensitive
        "search_term" => "xYz",
        "sort_by" => "symbol",
        "sort_dir" => "desc"
      }

      response = user_request("/token.all", attrs)
      tokens = response["data"]["data"]

      assert response["success"]
      assert Enum.count(tokens) == 3
      assert Enum.at(tokens, 0)["symbol"] == "XYZ3"
      assert Enum.at(tokens, 1)["symbol"] == "XYZ2"
      assert Enum.at(tokens, 2)["symbol"] == "XYZ1"
    end
  end

  describe "/token.get" do
    test "returns a token by the given ID" do
      tokens = insert_list(3, :token)
      # Pick the 2nd inserted token
      target = Enum.at(tokens, 1)
      response = user_request("/token.get", %{"id" => target.id})

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert response["data"]["id"] == target.id
    end

    test "returns 'token:id_not_found' if the given ID was not found" do
      response = user_request("/token.get", %{"id" => "wrong_id"})

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "token:id_not_found"

      assert response["data"]["description"] ==
               "There is no token corresponding to the provided id"
    end

    test "returns 'client:invalid_parameter' if id was not provided" do
      response = user_request("/token.get", %{"not_id" => "token_id"})

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "client:invalid_parameter"
      assert response["data"]["description"] == "Invalid parameter provided"
    end
  end

  describe "/token.create" do
    test "inserts a new token" do
      response =
        user_request("/token.create", %{
          symbol: "BTC",
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100,
          metadata: %{something: "interesting"},
          encrypted_metadata: %{something: "secret"}
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert response["data"]["metadata"] == %{"something" => "interesting"}
      assert response["data"]["encrypted_metadata"] == %{"something" => "secret"}
      assert Token.get(response["data"]["id"]) != nil
      assert mint == nil
    end

    test "inserts a new token with no minting if amount is nil" do
      response =
        user_request("/token.create", %{
          symbol: "BTC",
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100,
          amount: nil
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert Token.get(response["data"]["id"]) != nil
      assert mint == nil
    end

    test "inserts a new token with no minting if amount is a string" do
      response =
        user_request("/token.create", %{
          symbol: "BTC",
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100,
          amount: "100"
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert Token.get(response["data"]["id"]) != nil
      assert mint == nil
    end

    test "fails a new token with no minting if amount is 0" do
      response =
        user_request("/token.create", %{
          symbol: "BTC",
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100,
          amount: 0
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert Token.get(response["data"]["id"]) != nil
      assert mint == nil
    end

    test "mints the given amount of tokens" do
      response =
        user_request("/token.create", %{
          symbol: "BTC",
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100,
          amount: 1_000 * 100
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert Token.get(response["data"]["id"]) != nil
      assert mint != nil
      assert mint.confirmed == true
    end

    test "returns insert error when attrs are invalid" do
      response =
        user_request("/token.create", %{
          name: "Bitcoin",
          description: "desc",
          subunit_to_unit: 100
        })

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "client:invalid_parameter"

      assert response["data"]["description"] ==
               "Invalid parameter provided `symbol` can't be blank."

      inserted = Token |> Repo.all() |> Enum.at(0)
      assert inserted == nil
    end
  end

  describe "/token.mint" do
    test "mints an existing token" do
      token = insert(:token)

      response =
        user_request("/token.mint", %{
          id: token.id,
          amount: 1_000_000 * token.subunit_to_unit
        })

      mint = Mint |> Repo.all() |> Enum.at(0)

      assert response["success"]
      assert response["data"]["object"] == "token"
      assert Token.get(response["data"]["id"]) != nil
      assert mint != nil
      assert mint.amount == 1_000_000 * token.subunit_to_unit
      assert mint.token_uuid == token.uuid
    end

    test "fails to mint a non existing token" do
      response =
        user_request("/token.mint", %{
          id: "123",
          amount: 1_000_000
        })

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "token:id_not_found"
    end

    test "fails to mint with mint amount sent as string" do
      token = insert(:token)

      response =
        user_request("/token.mint", %{
          id: token.id,
          amount: "abc"
        })

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "client:invalid_parameter"
      assert response["data"]["description"] == "invalid_parameter"
    end

    test "fails to mint with mint amount == 0" do
      token = insert(:token)

      response =
        user_request("/token.mint", %{
          id: token.id,
          amount: 0
        })

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "client:invalid_parameter"

      assert response["data"]["description"] ==
               "Invalid parameter provided `amount` must be greater than %{number}."

      assert response["data"]["messages"] == %{"amount" => ["number"]}
    end

    test "fails to mint with mint amount < 0" do
      token = insert(:token)

      response =
        user_request("/token.mint", %{
          id: token.id,
          amount: -1
        })

      refute response["success"]
      assert response["data"]["object"] == "error"
      assert response["data"]["code"] == "client:invalid_parameter"

      assert response["data"]["description"] ==
               "Invalid parameter provided `amount` must be greater than %{number}."

      assert response["data"]["messages"] == %{"amount" => ["number"]}
    end
  end
end
