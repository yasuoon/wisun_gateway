defmodule WisunGateway.Wisun.Server do
  use GenServer

  alias WisunGateway.Tools
  alias WisunGateway.Wisun

  require Logger

  defmodule State do
    defstruct opts: nil, step: nil, ids: %{}
  end

  @sensor_port 0x123
  @send_port 0x778
  @send_delay 600
  @interval 10


  def notice(cmd, data) do
    GenServer.cast(__MODULE__, {:notice, cmd, data})
  end

  @doc """
  通知メッセージを受信時にWisunGateWay.Wisun.Portから呼び出される

  ## 引数
    - cmd  : 応答コマンド
    - data : 応答パラメータ

  ## 戻り値
    (atom) センサーのステップを表す
  """
  def notice_proc(0x6018, <<
    ipv6 :: binary-size(16),
    _src_port :: binary-size(2), _dest_port :: binary-size(2),
    _panid :: binary-size(2), _cast, _crypt, rssi,
    len :: binary-size(2), data :: binary
    >>)
  do

    _data_len = Tools.bin_to_int(len)

    mac = Wisun.mac_from_ipv6(ipv6)
    log = "[UDP Receive Message]  MAC: #{Base.encode16(mac)}, Data: #{inspect(data)} RSSI: #{rssi - 256}dBm"
    Logger.info(log)

    command_from_sensor(ipv6, data)
  end

  def notice_proc(cmd, data) do
    cmd_s = Tools.int_to_string(cmd, 4, 16)
    log = "Notice: #{cmd_s}, #{Base.encode16(data)}"
    Logger.info(log)
    :other
  end

  def command_from_sensor(ipv6, <<0x01, 0x02>>) do
    Logger.info("Command from Sensor: Request Mode")
    args = [ipv6, @send_port, @sensor_port]
    {:request_mode, args}
  end

  def command_from_sensor(ipv6, <<0x02, id_gateway, id_client>>) do
    Logger.info("Command from Sensor: Resuest Sensor Type")
    d = <<0x12, id_gateway, id_client, 1, 1, 1, 0, 0, 0, 0, 0, 0>>
    args = [ipv6, @send_port, @sensor_port, d]
    {:request_sensor_type, args}
  end

  def command_from_sensor(ipv6, <<0x03, id_gateway, id_client>>) do
    Logger.info("Command from Sensor: Request Time Now")
    now = jst_now()
    d = <<0x13, id_gateway, id_client,
      now.year :: integer-16, now.month, now.day, now.hour, now.minute, now.second>>
    args = [ipv6, @send_port, @sensor_port, d]
    {:request_time, args}
  end

  def command_from_sensor(ipv6, <<0x04, id_gateway, id_client>>) do
    Logger.info("Command from Sensor: Request Interval")
    d = <<0x14, id_gateway, id_client, @interval>>
    args = [ipv6, @send_port, @sensor_port, d]
    {:request_interval, args}
  end

  def command_from_sensor(ipv6, <<0x40,
    id_gateway, id_client,
    0x00, year :: integer-unsigned-16, month, day, hour, minute, sec,
    0x01, temp :: integer-signed-32, 0x02, humi :: integer-signed-32,
    >>)
  do
    temp_v = temp / 1000
    humi_v = humi / 1000
    Logger.info("Command from Sensor: Temp[#{temp_v} ℃], Humi[#{humi_v} %]")
    d = <<50, id_gateway, id_client, 0, 0>>
    args = [ipv6, @send_port, @sensor_port, d]

    mac = Wisun.mac_from_ipv6(ipv6)
    Process.send_after(__MODULE__, {:del_device, mac}, @send_delay)
    {:get_data, args}
  end

  def command_from_sensor(_ipv6, data) do
    log = "Command from Sensor: #{Base.encode16(data)}"
    Logger.error(log)
    #Process.send_after(__MODULE__, {:del_device, mac}, @send_delay)
    {:error_data, nil}
  end

  def jst_now do
    diff = 9 * 3600 # 時差(9時間)
    NaiveDateTime.utc_now() |> NaiveDateTime.add(diff, :second)
  end

  @doc """
  PANAパラメータはWi-Sunデバイスのモードによって
  適切な設定の方法を選択する
  """
  def init_pana_param(opts) do
    case opts[:mode] do
      :dev -> nil
      :crdi -> init_pana_param_crdi(opts)
      :panc -> init_pana_param_panc(opts)
      :dual -> init_pana_param_panc(opts)
    end
  end


  @doc """
  コーディネーター用のPANAパラメータ設定
  """
  def init_pana_param_crdi(opts) do
    pass = opts[:pass]

    {:ok, _} = Wisun.cmd_han_set_pana_param(pass)
    {:ok, _} = Wisun.cmd_han_pana_start()
  end


  @doc """
  PANコーディネーター用のPANAパラメータ設定
  """
  def init_pana_param_panc(opts) do
    pass = opts[:pass]

    Enum.each(opts[:dev_macs], fn mac ->
      {:ok, _} =
        Tools.int_to_bin(mac, 8)
        |> Wisun.cmd_han_set_pana_param(pass)
    end)
    {:ok, _} = Wisun.cmd_han_pana_start()
  end

  @doc """
  モードリクエストに返答するメッセージを作成
  """
  def response_mode(ids, args) do
    ipv6 = hd(args)
    ids = Map.put_new(ids, ipv6, Enum.count(ids) + 1)
    #<<cmd, id_gw, id_client, mode, sync_time, sleep>>
    data = <<11, 1, ids[ipv6], 1, 1, 1>>
    {ids, args ++ [data]}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  @impl true
  def init(opts) do
    :ok = Wisun.cmd_com_reset()
    {:ok, addr} = Wisun.cmd_com_get_mac_addr()
    Logger.debug("MAC: #{Base.encode16(addr)}")
    {:ok, _} = Wisun.cmd_com_init(opts[:mode], opts[:sleep], opts[:channel], opts[:tx_power])
    {:ok, _} = Wisun.cmd_han_start()
    init_pana_param(opts)
    Enum.each(opts[:open_ports], fn port ->
      {:ok, _} = Wisun.cmd_com_open_port(port)
    end)

    {:ok, %State{opts: opts}}
  end

  @impl true
  def handle_cast({:notice, cmd, data}, state) do
    prev = state.step
    {new_step, new_ids, send_data} = case notice_proc(cmd, data) do
      :other -> {state.step, state.ids, nil}
      #{^prev, _} -> Logger.warn("Retry Received: #{prev}"); prev
      {:request_mode, args} -> {ids, data} = response_mode(state.ids, args)
        {:request_mode, ids, data}
      {step, args} -> {step, state.ids, args}
    end

    GenServer.cast(__MODULE__, {:send_message_to_sensor, send_data})

    {:noreply, %{state | step: new_step, ids: new_ids}}
  end

  @impl true
  def handle_cast({:send_message_to_sensor, nil}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message_to_sensor, args}, state) do
    {:ok, _} = apply(Wisun, :cmd_com_send_data, args)
    {:noreply, state}
  end

  @impl true
  def handle_info({:delay_message_to_sensor, nil}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:delay_message_to_sensor, args}, state) do
    {:ok, _} = apply(Wisun, :cmd_com_send_data, args)
    {:noreply, state}
  end

  @impl true
  def handle_info({:del_device, mac}, state) do

    {:ok, _} = Wisun.cmd_han_del_device_list(mac)

    {:noreply, state}
  end
end
