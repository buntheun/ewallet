use Mix.Config

config :local_ledger_db, LocalLedgerDB.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  url: {:system, "LOCAL_LEDGER_DATABASE_URL", "postgres://localhost/local_ledger_test"}

config :cloak, Salty.SecretBox.Cloak,
  tag: "SBX",
  default: true,
  keys: [
    %{
      tag: <<1>>,
      key: "j6fy7rZP9ASvf1bmywWGRjrmh8gKANrg40yWZ-rSKpI",
      default: true
    }
  ]
