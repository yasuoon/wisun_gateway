defmodule WisunGateway.Wisun.Messages do
  @moduledoc """
  Socketサーバーへ送信するメッセージを一時保管するキュー
  Socketサーバーへすぐに送信できないときのためのバッファ
  """
  use Agent

  defstruct messages: nil,
    max: 1_000

  def start_link(_arg) do
    Agent.start_link(fn -> %__MODULE__{messages: :queue.new()} end,
      name: __MODULE__
    )
  end

  def push(msg) do
    Agent.update(__MODULE__, fn state ->
      mss = :queue.in(msg, state.messages)

      new = fit_length(mss, state.max)

      %{state | messages: new}
    end)
  end

  defp fit_length(messages, max) do
    if :queue.len(messages) > max do
      fit_length(:queue.drop(messages), max)
    else
      messages
    end
  end

  def pop do
    Agent.get_and_update(__MODULE__, fn state ->
      {v, rest} = case :queue.out(state.messages) do
        {:empty, rest} -> {:empty, rest}
        {{:value, v}, rest} -> {v, rest}
      end

      {v, %{state | messages: rest}}
    end)
  end

  def get_all do
    Agent.get(__MODULE__, &(&1.messages |> :queue.to_list))
  end
end
