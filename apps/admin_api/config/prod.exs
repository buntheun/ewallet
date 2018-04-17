use Mix.Config

# Configs for Bamboo emailing library
config :admin_api, AdminAPI.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: {:system, "SMTP_HOST"},
  port: {:system, "SMTP_PORT"},
  username: {:system, "SMTP_USER"},
  password: {:system, "SMTP_PASSWORD"}
