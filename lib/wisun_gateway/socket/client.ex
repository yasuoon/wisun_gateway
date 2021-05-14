defmodule WisunGateway.Socket.Client do
  use GenServer

  require Logger

  defmodule State do
    defstruct opts: nil, socket: nil
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    #Process.send_after(self(), :connect, 10)

    {:ok, %State{opts: opts}}
  end


  @impl true
  def handle_info(:connect, state) do
    {ip, port} = state.opts[:server]

    socket = case :gen_tcp.connect(ip, port, [:binary, active: true]) do
      {:ok, sock} -> sock
      {:error, reason} -> Logger.error("Socket connection failure: #{reason}")
        Process.send_after(self(), :connect, 60_000)
        nil
    end

    {:noreply, %{state | socket: socket}}
  end
end
