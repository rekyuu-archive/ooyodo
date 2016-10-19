defmodule Ooyodo.Bot do
  use Ooyodo.Module

  handle :text do
    command "ping", do: reply send_message("Pong!")
    match ["hi", "hello"], do: reply send_message("Hello!")
  end
end
