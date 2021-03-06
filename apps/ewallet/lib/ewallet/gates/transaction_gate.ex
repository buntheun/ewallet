defmodule EWallet.TransactionGate do
  @moduledoc """
  Handles the logic for a transfer of value from an account to a user. Delegates the
  actual transfer to EWallet.TransferGate once the wallets have been loaded.
  """
  alias EWallet.{
    TransferGate,
    CreditDebitRecordFetcher,
    AddressRecordFetcher,
    WalletCreditDebitAssigner
  }

  alias EWalletDB.{Transfer, User}

  def credit_type, do: "credit"
  def debit_type, do: "debit"

  @doc """
  Process a transaction between two addresses.

  ## Examples

    res = Transaction.process_with_addresses(%{
      "from_address" => "81e75f46-ee14-4e4c-a1e5-cddcb26dce9c",
      "to_address" => "4aa07691-2f99-4cb1-b36c-50763e2d2ba8",
      "token_id" => "tok_OMG_01cbffwvj6ma9a9gg1tb24880q",
      "amount" => 100_000,
      "metadata" => %{some: "data"},
      "encrypted_metadata" => %{some: "secret"},
      "idempotency_token" => idempotency_token
    })

    case res do
      {:ok, transfer, changed_wallets, token} ->
        # Everything went well, do something.
      {:error, transfer, code, description} ->
        # Something went wrong with the transfer processing.
    end

  """
  def process_with_addresses(
        %{
          "from_address" => _,
          "to_address" => _,
          "token_id" => _,
          "amount" => _,
          "idempotency_token" => _
        } = attrs
      ) do
    with {:ok, from, to, token} <- AddressRecordFetcher.fetch(attrs),
         {:ok, transfer} <- get_or_insert_transfer(from, to, token, attrs) do
      process_with_transfer(transfer, [from, to], token)
    else
      error -> error
    end
  end

  @doc """
  Process a transaction, starting with the creation or retrieval of a transfer record (using
  the given idempotency token), then calling the Transfer.process function to add the transaction
  to the ledger(s).

  ## Examples

    res = Transaction.process_credit_or_debit(%{
      "account_id" => "510f32b5-17f4-4c5c-86f2-aad1396330f9", # Optional
      "burn_wallet_identifier" => "burn", # Optional
      "provider_user_id" => "sample_provider_user_id",
      "token_id" => "tok_OMG_01cbffwvj6ma9a9gg1tb24880q",
      "amount" => 100_000,
      "type" => Transaction.debit_type,
      "metadata" => %{some: "data"},
      "encrypted_metadata" => %{some: "secret"},
      "idempotency_token" => idempotency_token
    })

    case res do
      {:ok, changed_wallets, token} ->
        # Everything went well, do something.
      {:error, code, description} ->
        # Something went wrong with the transfer processing.
    end

  """
  def process_credit_or_debit(
        %{
          "provider_user_id" => _,
          "token_id" => _,
          "amount" => _,
          "idempotency_token" => _,
          "type" => type
        } = attrs
      ) do
    with {:ok, account, user, token} <- CreditDebitRecordFetcher.fetch(attrs),
         {:ok, from, to} <-
           WalletCreditDebitAssigner.assign(%{
             account: account,
             user: user,
             type: type,
             burn_wallet_identifier: attrs["burn_wallet_identifier"]
           }),
         {:ok, transfer} <- get_or_insert_transfer(from, to, token, attrs) do
      user_wallet = User.get_preloaded_primary_wallet(user)
      process_with_transfer(transfer, [user_wallet], token)
    else
      error -> error
    end
  end

  defp get_or_insert_transfer(
         from,
         to,
         token,
         %{
           "amount" => amount,
           "idempotency_token" => idempotency_token
         } = attrs
       ) do
    TransferGate.get_or_insert(%{
      idempotency_token: idempotency_token,
      from: from.address,
      to: to.address,
      token_id: token.id,
      amount: amount,
      metadata: attrs["metadata"] || %{},
      encrypted_metadata: attrs["encrypted_metadata"] || %{},
      payload: attrs
    })
  end

  defp process_with_transfer(%Transfer{status: "pending"} = transfer, wallets, token) do
    transfer
    |> TransferGate.process()
    |> process_with_transfer(wallets, token)
  end

  defp process_with_transfer(%Transfer{status: "confirmed"} = transfer, wallets, token) do
    {:ok, transfer, wallets, token}
  end

  defp process_with_transfer(%Transfer{status: "failed"} = transfer, _wallets, _token) do
    resp = transfer.ledger_response
    {:error, transfer, resp["code"], resp["description"]}
  end
end
