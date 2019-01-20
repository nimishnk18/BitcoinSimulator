defmodule BitcoinComplete.Repo do
  use Ecto.Repo,
    otp_app: :bitcoin_complete,
    adapter: Ecto.Adapters.Postgres
end
