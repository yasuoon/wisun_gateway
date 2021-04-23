defmodule WisunGateway.Wisun.Framing do
  @behaviour Circuits.UART.Framing

  alias WisunGateway.Tools

  require Logger

  defstruct rx_buffer: <<>>


  @impl true
  def init(_args) do
    {:ok, %__MODULE__{}}
  end


  @impl true
  def add_framing(
    <<unique :: binary-size(4),
    cmd :: binary-size(2),
    data :: binary >>,
    state)
  do

    len = (byte_size(data) + 4) |> Tools.int_to_bin(2)

    head = unique <> cmd <> len

    chksum_h = checksum(head)
    chksum_d = checksum(data)

    framed_data = head <> chksum_h <> chksum_d <> data

    #Logger.debug(inspect framed_data)

    {:ok, framed_data, state}
  end


  @impl true
  def remove_framing(data, state) do
    process_data(state.rx_buffer <> data, [])
  end


  @impl true
  def frame_timeout(state) do
    new_state = %{state | rx_buffer: <<>>}

    {:ok, [], new_state}
  end


  @impl true
  def flush(direction, state) when direction == :receive or direction == :both do
    %{state | rx_buffer: <<>>}
  end


  @impl true
  def flush(:transmit, state) do
    state
  end


  # チェックサム計算
  defp checksum(bin) do
    :binary.bin_to_list(bin)
    |> Enum.sum()
    |> Tools.int_to_bin(2)
  end


  # チェックサム照合
  defp verify_checksum(data, chksum) do
    checksum(data) == chksum
  end

  # 受信データ処理
  defp process_data(rx_data, messages) when byte_size(rx_data) < 12 do
    {:in_frame, messages, %__MODULE__{rx_buffer: rx_data}}
  end


  defp process_data(
    <<uniquecode :: binary-size(4), cmd :: binary-size(2), len :: binary-size(2),
    chksum_head :: binary-size(2), chksum_data :: binary-size(2),
    data :: binary>> = rx_data,
    messages)
  do
    data_len = Tools.bin_to_int(len) - 4
    {data1, rest} = Tools.bin_split_at(data, data_len)

    msg = %{unique: uniquecode, cmd: cmd, len: len,
      chksum_head: chksum_head, chksum_data: chksum_data, 
      data: data1, rest: rest
    }

    case byte_size(data) < data_len do
      true  -> {:in_frame, messages, %__MODULE__{rx_buffer: rx_data}}
      false -> process_message(msg, messages)
    end
  end


  defp process_message(msg, messages) do
    head = msg.unique <> msg.cmd <> msg.len

    chk = verify_checksum(head, msg.chksum_head) and
      verify_checksum(msg.data, msg.chksum_data) 

    case chk do
      false -> {:error, :checksum}
      true -> process_message2(msg, messages)
    end
  end


  defp process_message2(msg, messages) do
    cmd = Tools.bin_to_int(msg.cmd)

    new_msg = {msg.unique, cmd, msg.data}

    new_messages = [new_msg | messages]
                   |> Enum.reverse()
    case msg.rest do
      "" -> {:ok, new_messages, %__MODULE__{}}
      rest -> {:in_frame, new_messages, %__MODULE__{rx_buffer: rest}}
    end
  end
end
