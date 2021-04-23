defmodule WisunGateway.Socket.Supervisor do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, sock_opts} = Application.fetch_env(:wisun_gateway, Socket)

    children = [
      {WisunGateway.Socket.Client, sock_opts},
    ]

    opts = [strategy: :rest_for_one]

    Supervisor.init(children, opts)
  end
end
