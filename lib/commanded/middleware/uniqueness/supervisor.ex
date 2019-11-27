defmodule Commanded.Middleware.Uniqueness.Supervisor do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = Commanded.Middleware.Uniqueness.Adapter.inject_child_spec([])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Commanded.Middleware.Uniqueness.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
