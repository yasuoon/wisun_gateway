defmodule WisunGateway.Tools do
  @moduledoc """
  共通で仕様するツール
  """

  @doc """
  整数値をbinaryに変換する

  ## 引数
    - num : (integer) 変換する数値
    - len : (integer) 長さ

  ## 戻り値
  (binary) 変換結果

  ## Examples
  
      iex> WisunGateway.Tools.int_to_bin(0x01020304, 3)
      <<2, 3, 4>>

  """
  def int_to_bin(num, len) do
    Integer.digits(num, 0x100)
    |> Enum.reverse()
    |> Stream.concat(Stream.cycle [0])
    |> Stream.take(len)
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end


  @doc """
  binaryを整数値に変換する

  ## 引数
    - bin : (binary) 変換元のbinary

  ## 戻り値
  (integer) 変換結果

  ## Examples
  
      iex> WisunGateway.Tools.bin_to_int(<<1>>)
      1

      iex> WisunGateway.Tools.bin_to_int(<<1, 0>>)
      256

      iex> WisunGateway.Tools.bin_to_int(<<1, 200>>)
      456

  """
  def bin_to_int(bin) do
    :binary.bin_to_list(bin)
    |> Integer.undigits(0x100)
  end


  @doc """
  値を比較する
  ### 引数
    - a : 値a
    - b : 値b

  ### 戻り値
    - :lt : aはbより小さい (a < b の評価結果がtrue)
    - :eq : aとbは等しい (a == b の評価結果がtrue)
    - :gt : aはbより大きい (a > b の評価結果がtrue)
  """
  def compare(a, b) do
    case {a < b, a == b, a > b} do
      {true, _, _} -> :lt
      {_, true, _} -> :eq
      {_, _, true} -> :gt
    end
  end


  @doc """
  binaryを任意の位置で分割する

  ### 引数
    - bin : 対象のバイナリ
    - pos : 分割位置

  ### 戻り値
  ({binary, binary}) バイナリのタプル
  """
  def bin_split_at(bin, pos) do
    len = byte_size(bin)
    {len1, len2} = case {abs(pos) > len, pos < 0} do
      {true,  true}  -> {0, len}
      {true,  false} -> {len, 0}
      {false, true}  -> {len + pos, abs(pos)}
      {false, false} -> {pos, len - pos}
    end

    a = binary_part(bin, 0, len1)
    b = binary_part(bin, len1, len2)
    {a, b}
  end
end
