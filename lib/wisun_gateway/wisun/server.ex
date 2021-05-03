defmodule WisunGateway.Wisun.Server do
  use GenServer

  alias WisunGateway.Tools
  alias WisunGateway.Wisun

  require Logger


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

    process_message(data)

    mac = Wisun.mac_from_ipv6(ipv6)
    log = "[UDP message]  MAC: #{Base.encode16(mac)}, RSSI: #{rssi - 256}dBm"
    Logger.info(log)

    args = [ipv6, 23456, 0x456, <<0xA>>]
    Process.send_after(__MODULE__, {:delay_msg, args}, 500)
    :ok
  end


  def notice_proc(cmd, data) do
    Logger.info(inspect {"Notice Message", cmd, data})
    :ok
  end


  def process_message(data) do
    Logger.debug(inspect {"Sensor Message", data})
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
