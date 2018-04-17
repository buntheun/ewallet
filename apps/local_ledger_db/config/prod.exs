use Mix.Config

config :local_ledger_db, LocalLedgerDB.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: {:system, "LOCAL_LEDGER_DATABASE_URL", "postgres://localhost/local_ledger_prod"}

# Cloak doesn't support {:system, ...}-style configuration so we
# have to set REPLACE_OS_VARS=yes when running the app release.
config :cloak, Salty.SecretBox.Cloak,
  tag: "SBX",
  default: true,
  keys: [
    %{
      tag: <<1>>,
      key: "${LOCAL_LEDGER_SECRET_KEY}",
      default: true
    }
  ]
