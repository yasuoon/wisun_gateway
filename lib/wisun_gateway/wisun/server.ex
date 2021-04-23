defmodule WisunGateway.Wisun.Server do
  use GenServer

  #alias WisunGateway.Tools
  alias WisunGateway.Wisun

  require Logger


  def notify(cmd, data) do
    Logger.info(inspect {"Notify Message", cmd, data})
  end

  def init_pana_param(opts) do
    case opts[:mode] do
      :dev -> nil
      :crdi -> init_pana_param_crdi(opts)
      :panc -> init_pana_param_panc(opts)
      :dual -> init_pana_param_panc(opts)
    end
  end


  def init_pana_param_crdi(opts) do
    pass = opts[:pass]

    Wisun.cmd_han_set_pana_param(pass)
    Wisun.cmd_han_pana_start()
  end


  def init_pana_param_panc(opts) do
    pass = opts[:pass]

    Enum.each(opts[:dev_macs], fn mac ->
      Wisun.cmd_han_set_pana_param(mac, pass)
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
    Logger.debug("MAC: #{Integer.to_string(addr, 16)}")
    Wisun.cmd_com_init(opts[:mode], opts[:sleep], opts[:channel], opts[:tx_power])
    Wisun.cmd_han_start()
    init_pana_param(opts)
    Enum.each(opts[:open_ports], fn port ->
      Wisun.cmd_com_open_port(port)
    end)

    {:ok, opts}
  end
end
