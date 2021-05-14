defmodule WisunGateway.Wisun.Server do
  use GenServer

  alias WisunGateway.Tools
  alias WisunGateway.Wisun

  require Logger

  @sensor_port 0x456
  @send_port 0x778


  def notice(cmd, data) do
    GenServer.cast(__MODULE__, {:notice, cmd, data})
  end

  @doc """
  通知メッセージを受信時にWisunGateWay.Wisun.Portから呼び出される

  ## 引数
    - cmd  : 応答コマンド
    - data : 応答パラメータ

  ## 戻り値
  :ok
  """
  def notice_proc(0x6018, <<
    ipv6 :: binary-size(16),
    _src_port :: binary-size(2), _dest_port :: binary-size(2),
    _panid :: binary-size(2), _cast, _crypt, rssi,
    len :: binary-size(2), data :: binary
    >>)
  do

    _data_len = Tools.bin_to_int(len)

    command_from_sensor(ipv6, data)

    mac = Wisun.mac_from_ipv6(ipv6)
    log = "[UDP message]  MAC: #{Base.encode16(mac)}, RSSI: #{rssi - 256}dBm"
    Logger.info(log)

    :ok
  end

  def notice_proc(cmd, data) do
    cmd_s = Tools.int_to_string(cmd, 4, 16)
    log = "Notice: #{cmd_s}, #{Base.encode16(data)}"
    Logger.info(log)
    :ok
  end

  def command_from_sensor(ipv6, <<"01", "2", "\r\n">>) do
    Logger.debug("CMD from Sensor : Request Mode")
    d = <<"11", "1", "01", "1", "0", "0", "\r\n">>
    args = [ipv6, @send_port, @sensor_port, d]
    GenServer.cast(__MODULE__, {:send_message_to_sensor, args})
  end

  def command_from_sensor(ipv6, <<"02", id_gateway :: binary-size(1), id_client :: binary-size(2), "\r\n">>) do
    Logger.debug("CMD from Sensor : Resuest Sensor Type")
    d = <<"12", id_gateway :: binary, id_client :: binary, "0", "1", "1", "000000", "\r\n">>
    args = [ipv6, @send_port, @sensor_port, d]
    GenServer.cast(__MODULE__, {:send_message_to_sensor, args})
  end

  def command_from_sensor(ipv6, <<"40",
    id_gateway :: binary-size(1), id_client :: binary-size(2),
    "01", temp :: binary-size(6), "02", humi :: binary-size(6),
    "\r\n">>)
  do
    Logger.debug("CMD from Sensor : Temp[#{temp}], Humi[#{humi}]")
    d = <<"50", id_gateway :: binary, id_client :: binary, "00", "\r\n">>
    args = [ipv6, @send_port, @sensor_port, d]
    GenServer.cast(__MODULE__, {:send_message_to_sensor, args})

    mac = Wisun.mac_from_ipv6(ipv6)
    Process.send_after(__MODULE__, {:del_device, mac}, 500)
  end

  def command_from_sensor(_ipv6, data) do
    log = "Sensor: #{Base.encode16(data)}"
    Logger.debug(log)
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

    Wisun.cmd_han_set_pana_param(pass)
    Wisun.cmd_han_pana_start()
  end


  @doc """
  PANコーディネーター用のPANAパラメータ設定
  """
  def init_pana_param_panc(opts) do
    pass = opts[:pass]

    Enum.each(opts[:dev_macs], fn mac ->
      Tools.int_to_bin(mac, 8)
      |> Wisun.cmd_han_set_pana_param(pass)
    end)
    Wisun.cmd_han_pana_start()
  end


  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  @impl true
  def init(opts) do
    Wisun.cmd_com_reset()
    {:ok, addr} = Wisun.cmd_com_get_mac_addr()
    Logger.debug("MAC: #{Base.encode16(addr)}")
    Wisun.cmd_com_init(opts[:mode], opts[:sleep], opts[:channel], opts[:tx_power])
    Wisun.cmd_han_start()
    init_pana_param(opts)
    Enum.each(opts[:open_ports], fn port ->
      Wisun.cmd_com_open_port(port)
    end)

    {:ok, opts}
  end

  @impl true
  def handle_cast({:notice, cmd, data}, state) do
    notice_proc(cmd, data)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message_to_sensor, args}, state) do
    apply(Wisun, :cmd_com_send_data, args)
    {:noreply, state}
  end

  @impl true
  def handle_info({:delay_msg, args = [ipv6 | _rest]}, state) do

    apply(Wisun, :cmd_com_send_data, args)

    mac = Wisun.mac_from_ipv6(ipv6)
    Process.send_after(__MODULE__, {:del_device, mac}, 500)

    {:noreply, state}
  end

  @impl true
  def handle_info({:del_device, mac}, state) do

    Wisun.cmd_han_del_device_list(mac)

    {:noreply, state}
  end
end
