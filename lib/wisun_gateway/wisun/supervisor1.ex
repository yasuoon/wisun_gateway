defmodule WisunGateway.Wisun.Supervisor1 do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      WisunGateway.Wisun.Messages,
      WisunGateway.Wisun.Supervisor2
    ]

    opts = [strategy: :one_for_one]

    Supervisor.init(children, opts)
  end
end
