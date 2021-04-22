defmodule WisunGatewayTest do
  use ExUnit.Case
  doctest WisunGateway

  test "greets the world" do
    assert WisunGateway.hello() == :world
  end
end
