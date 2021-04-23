defmodule WisunGateway.Wisun do

  alias WisunGateway.Tools
  alias WisunGateway.Wisun.Port, as: WisunPort

  @doc """
  ユニークコード
  """
  def uniquecode(:request),  do: <<0xD0, 0xEA, 0x83, 0xFC>>
  def uniquecode(:response), do: <<0xD0, 0xF9, 0xEE, 0x5D>>
  def uniquecode(:notify),   do: <<0xD0, 0xF9, 0xEE, 0x5D>>

  @doc """
  動作モード
  """
  def han_mode(:panc), do: 0x01
  def han_mode(:crdi), do: 0x02
  def han_mode(:dev),  do: 0x03
  def han_mode(:dual), do: 0x05

  @doc """
  スリープ機能
  """
  def han_sleep(false), do: 0x00
  def han_sleep(true),  do: 0x01

  @doc """
  送信出力
  """
  def tx_power(20), do: 0x00
  def tx_power(10), do: 0x01
  def tx_power(1),  do: 0x02


  @doc """
  MACアドレスをIPV6アドレスに変換

  ## 引数 
    - mac : (integer) MACアドレス

  ## 戻り値
  (binary) IPV6アドレス
  """
  def mac_to_ipv6(mac) do
      <<x, xs :: binary>> = Tools.int_to_bin(mac, 8)
      pre = <<0xFE, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
      pre <> <<Bitwise.bxor(x, 0x02)>> <> xs
  end


  @doc """
  IPV6アドレスをMACアドレスに変換

  ## 引数 
    - ipv6 : (binary) IPV6アドレス

  ##  戻り値
  (integer) MACアドレス
  """
  def mac_from_ipv6(_ipv6 = <<_pre :: binary-size(8), x, xs :: binary-size(7)>>) do
      <<Bitwise.bxor(x, 0x02)>> <> xs
      |> Tools.bin_to_int()
  end


  ################################
  # Wi-Sun コマンド
  #
  ################################


  @doc """
  (共通) ステータス取得
  """
  def cmd_com_get_status do
    WisunPort.send_request(0x0001)
  end


  @doc """
  (共通) UDPポートOPEN状態
  """
  def cmd_com_get_udp_opend do
    WisunPort.send_request(0x0007)
  end


  @doc """
  (共通) IPアドレス取得
  """
  def cmd_com_get_ip_addr do
    WisunPort.send_request(0x0009)
  end


  @doc """
  (共通) MACアドレス取得
  """
  def cmd_com_get_mac_addr do
    case WisunPort.send_request(0x000E) do
      {:ok, bin} -> {:ok, Tools.bin_to_int(bin)}
      error -> error
    end
  end


  @doc """
  (共通) 接続状態取得
  """
  def cmd_com_get_connections do
    WisunPort.send_request(0x0011)
  end


  @doc """
  (共通) 端末情報取得
  """
  def cmd_com_get_terminals do
    WisunPort.send_request(0x0100)
  end


  @doc """
  (共通) 初期設定取得
  """
  def cmd_com_get_init do
    WisunPort.send_request(0x0107)
  end

  @doc """
  (共通) 初期設定
  """
  def cmd_com_init(mode, sleep, ch, power) do
    data = <<han_mode(mode), han_sleep(sleep), ch, tx_power(power)>>
    WisunPort.send_request(0x005F, data: data)
  end


  @doc """
  (共通) UDPポートOPEN
  """
  def cmd_com_open_port(num) do
    data = Tools.int_to_bin(num, 2)
    WisunPort.send_request(0x0005, data: data)
  end


  @doc """
  (共通) UDPポートCLOSE
  """
  def cmd_com_close_port(num) do
    data = Tools.int_to_bin(num, 2)
    WisunPort.send_request(0x0006, data: data)
  end


  @doc """
  (共通) データ送信
  """
  def cmd_com_send_data(ipv6, src_port, dest_port, arg) do
    data = [ipv6,
      Tools.int_to_bin(src_port, 2),
      Tools.int_to_bin(dest_port, 2),
      Tools.int_to_bin(byte_size(arg), 2),
      arg
    ]
    WisunPort.send_request(0x0008, data: data)
  end


  @doc """
  (共通) Ping送信

  ## 引数 
    - ipv6 : (binary) IPv6アドレス
    - type : (0x00) 任意データ
             (0x01) 固定データパターン1 ("a" - "z")
             (0x02) 固定データパターン2 ("0001"からインクリメント)
    - arg : (binary) 送信データ
  """
  def cmd_com_send_ping(ipv6, type \\ 0x01, arg \\ <<>>) do
    len = case type do
      0x00 -> byte_size(arg)
      0x01 -> 1
      0x02 -> 1
    end
    data = [ipv6, Tools.int_to_bin(len, 2), type, arg]
    WisunPort.send_request(0x00D1, data: data)
  end


  @doc """
  (共通) バージョン情報取得
  """
  def cmd_com_get_version do
    WisunPort.send_request(0x006B)
  end


  @doc """
  (共通) ハードウェアリセット
  """
  def cmd_com_reset do
    WisunPort.send_request(0x00D9, response: 0x6019)
  end


  @doc """
  (HAN) グループ鍵有効期限取得
  """
  def cmd_han_get_group_key_validated_period do
    WisunPort.send_request(0x0013)
  end


  @doc """
  (HAN) 受入れ接続モード状態取得
  """
  def cmd_han_get_acception_mode do
    WisunPort.send_request(0x0026)
  end


  @doc """
  (HAN) グループ鍵取得
  """
  def cmd_han_get_group_key do
    WisunPort.send_request(0x0028)
  end


  @doc """
  (HAN) PANA認証情報取得
  """
  def cmd_han_get_pana_param do
    WisunPort.send_request(0x002D)
  end


  @doc """
  (HAN) PANA認証情報設定
  """
  def cmd_han_set_pana_param(mac \\ nil, password) do
    mac_bs = if mac, do: Tools.int_to_bin(mac, 8), else: <<>>
    WisunPort.send_request(0x002C, data: [mac_bs, password])
  end


  @doc """
  (HAN) PANA認証情報削除
  """
  def cmd_han_del_pana_param(mac \\ nil) do
    data = case mac do
      nil  -> <<>>
      :all -> <<>>
      _    -> Tools.int_to_bin(mac, 8)
    end
       
    WisunPort.send_request(0x002E, data: data)
  end


  @doc """
  (HAN) HAN動作開始
  """
  def cmd_han_start do
    wisun = Application.fetch_env!(:wisun_gateway, Wisun)
    id = Application.fetch_env!(:wisun_gateway, :id)

    data = case wisun[:mode] do
      :panc -> Tools.int_to_bin(id[:pan_id], 2)
      :crdi -> Tools.int_to_bin(id[:panc_mac], 8)
      :dev  -> Tools.int_to_bin(id[:panc_mac], 8)
      :dual -> Tools.int_to_bin(id[:pan_id], 2)
    end
       
    WisunPort.send_request(0x000A, data: data)
  end


  @doc """
  (HAN) HAN動作終了
  """
  def cmd_han_end do
    WisunPort.send_request(0x000B)
  end


  @doc """
  (HAN) 受入れ接続モード切り替え
  """
  def cmd_han_switch_acception_mode(mode) do
    data = case mode do
      :init -> <<0x01>>
      :norm -> <<0x02>>
    end

    WisunPort.send_request(0x0025, data: data)
  end


  @doc """
  (HAN) グループ鍵配信
  """
  def cmd_han_key_push do
    WisunPort.send_request(0x0029)
  end


  @doc """
  (HAN) PANA再認証
  """
  def cmd_han_reauthorization(mac) do
    data = Tools.int_to_bin(mac, 8)
    WisunPort.send_request(0x002B, data: data)
  end


  @doc """
  (HAN) PANA開始
  """
  def cmd_han_pana_start do
    WisunPort.send_request(0x003A)
  end


  @doc """
  (HAN) PANA終了
  """
  def cmd_han_pana_end do
    WisunPort.send_request(0x003B)
  end


  @doc """
  (HAN) デバイスリスト削除
  """
  def cmd_han_del_device_list(mac) do
    data = Tools.int_to_bin(mac, 8)
    WisunPort.send_request(0x006A, data: data)
  end


  @doc """
  (HAN) HAN切断
  """
  def cmd_han_disconnect(mac) do
    data = Tools.int_to_bin(mac, 8)
    WisunPort.send_request(0x00D3, data: data, response: [0x20D3, 0x206A])
  end
end
