defmodule WisunGateway.Wisun.Port do
  use GenServer

  require Logger

  alias Circuits.UART
  alias WisunGateway.Tools
  alias WisunGateway.Wisun

  defstruct port: nil,
    reply_info: nil

  @unique_req  Wisun.uniquecode(:request)
  @unique_res  Wisun.uniquecode(:response)
  @unique_not  Wisun.uniquecode(:notify)

  @success 0x01

  @doc """
  要求コマンドの送信

  ## 引数
    - cmd : (integer) 要求コマンド
  　- opts : (keyword) オプション
      * :data (binary) 要求コマンドに付加するデータ
      * :res (integer) 応答コマンド,
        要求コマンド送信後に返されることを期待する応答コマンド
  """
  def send_request(cmd, opts \\ []) do
    res = [Keyword.get(opts, :response, cmd + 0x2000)]
          |> List.flatten

    data = Keyword.get(opts, :data, <<>>)

    GenServer.call(__MODULE__, {:send_request, cmd, data, res})
  end


  def start_link(uart) do
    #Logger.debug(inspect uart)

    GenServer.start_link(__MODULE__, uart, name: __MODULE__)
  end


  @impl true
  def init(uart) do
    {:ok, port} = UART.start_link()

    :ok = UART.open(port, uart[:name], uart[:opts])

    {:ok, %__MODULE__{port: port}}
  end


  @impl true
  def handle_call({:send_request, cmd, data, res}, from, state) do
    send_data = [
      @unique_req,
      Tools.int_to_bin(cmd, 2),
      data
    ]
    UART.write(state.port, send_data)
    {:noreply, %{state | reply_info: {res, from}}}
  end


  @impl true
  def handle_info({:circuits_uart, _dev, {@unique_res, cmd, data}}, %{reply_info: {res, from}} = state) do
    res_data = case data do
      <<>> -> :ok
      <<@success, res :: binary>> -> {:ok, res}
      <<code, res :: binary>> -> {:error, code, res}
    end

    new_state = case {cmd in res, List.delete(res, cmd)} do
      {true, []} -> GenServer.reply(from, res_data)
        %{state | reply_info: nil}
      {true, res} -> %{state | reply_info: {res, from}}
      {false, []} -> notify(cmd, data)
        %{state | reply_info: nil}
      {false, _res} -> notify(cmd, data)
        state
    end

    {:noreply, new_state}
  end


  @impl true
  def handle_info({:circuits_uart, _dev, {@unique_not, cmd, data}}, state)
  when Bitwise.band(cmd, 0x4000) != 0
  do
    notify(cmd, data)
    {:noreply, state}
  end


  @impl true
  def handle_info({:circuits_uart, _dev, {@unique_res, cmd, data}}, state) do
    Logger.error(inspect {"Unknown Message Received", cmd, data})
    {:noreply, state}
  end


  defp notify(cmd, data) do
    WisunGateway.Wisun.Server.notify(cmd, data)
  end
end
