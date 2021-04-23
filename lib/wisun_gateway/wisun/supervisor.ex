defmodule WisunGateway.Wisun.Supervisor do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, uart} = Application.fetch_env(:wisun_gateway, UART)
    {:ok, wisun} = Application.fetch_env(:wisun_gateway, Wisun)
    {:ok, id} = Application.fetch_env(:wisun_gateway, :id)

    children = [
      {WisunGateway.Wisun.Port, uart},
      {WisunGateway.Wisun.Server, wisun ++ id},
    ]

    opts = [strategy: :rest_for_one]

    Supervisor.init(children, opts)
  end
end
