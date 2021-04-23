defmodule WisunGatewayTest do
  use ExUnit.Case
  doctest WisunGateway

  alias WisunGateway.Tools


  test "integer to binary" do
    assert Tools.int_to_bin(1, 1) == <<1>>
    assert Tools.int_to_bin(1, 4) == <<0, 0, 0, 1>>
    assert Tools.int_to_bin(0x1000000, 2) == <<0, 0>>
    assert Tools.int_to_bin(0x1000000, 4) == <<1, 0, 0, 0>>
  end


  test "binary to integer" do
    assert Tools.bin_to_int(<<0x0, 0x0, 0xA5>>) == 0xA5
    assert Tools.bin_to_int(<<0x5A, 0x0, 0xA5>>) == 0x5A00A5
  end


  test "binary split at position" do
    assert Tools.bin_split_at("1234567890",   0) == {"", "1234567890"}
    assert Tools.bin_split_at("1234567890",   1) == {"1", "234567890"}
    assert Tools.bin_split_at("1234567890",   5) == {"12345", "67890"}
    assert Tools.bin_split_at("1234567890",  10) == {"1234567890", ""}
    assert Tools.bin_split_at("1234567890",  11) == {"1234567890", ""}
    assert Tools.bin_split_at("1234567890",  -1) == {"123456789", "0"}
    assert Tools.bin_split_at("1234567890",  -3) == {"1234567", "890"}
    assert Tools.bin_split_at("1234567890", -10) == {"", "1234567890"}
    assert Tools.bin_split_at("1234567890", -11) == {"", "1234567890"}
  end
end
