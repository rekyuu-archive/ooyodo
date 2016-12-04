defmodule Ooyodo do
  @moduledoc """
  This starts the bot. Surprise! It uses `start/2`, invoked in `mix.exs`.
  """

  def start(_type, _args) do
    import Supervisor.Spec
    children = [supervisor(Ooyodo.Bot, [[name: Ooyodo.Bot]])]
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
