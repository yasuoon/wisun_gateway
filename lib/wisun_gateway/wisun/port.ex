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

    log_data = List.flatten(send_data) |> Enum.map(&Base.encode16/1)

    Logger.debug("send: #{inspect log_data}")

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
      {false, []} -> other_message(cmd, data)
        %{state | reply_info: nil}
      {false, _res} -> other_message(cmd, data)
        state
    end

    {:noreply, new_state}
  end


  @impl true
  def handle_info({:circuits_uart, _dev, {@unique_not, cmd, data}}, state) do
    other_message(cmd, data)
    {:noreply, state}
  end


  @impl true
  def handle_info(msg, state) do
    Logger.error(inspect {"Unknown Received", msg})
    {:noreply, state}
  end


  defp other_message(cmd, data) when Bitwise.band(cmd, 0x4000) != 0 do
    WisunGateway.Wisun.Server.notice(cmd, data)
  end

  defp other_message(cmd, data) do
    Logger.error(inspect {"Wi-Sun Bad Responce", cmd, data})
  end
end
