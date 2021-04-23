import Config

config :wisun_gateway, Wisun,
  mode: :panc,
  sleep: false,
  tx_power: 20,
  channel: 5,
  open_ports: [0x789]


config :wisun_gateway, UART,
  name: "ttymxc2",
  opts: [
    speed: 115200,
    data_bits: 8,  # データ長
    parity: :none, # パリティ
    stop_bits: 1,  # ストップビット
    flow_control: :none, # フロー制御
    framing: WisunGateway.Wisun.Framing, # フレーミング設定
    rx_framing_timeout: 10000, # 受信フレーミングタイムアウト(msec)
    active: true # 受信方法 active or passive
  ]


config :wisun_gateway, :operation,
  interval: 20 #(sec)


config :wisun_gateway, Socket,
  server: {{192, 168, 32, 83}, 10_000}


import_config "sub.exs"
