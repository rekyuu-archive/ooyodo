defmodule Ooyodo.Module do
  @bot_name Application.get_env(:ooyodo, :username)

  defmacro __using__(_options) do
    quote do
      import Ooyodo.Module
      import Nadia
      require Logger
      use GenServer

      def start_link(opts \\ []) do
        Logger.debug "Starting bot!"
        GenServer.start_link(__MODULE__, :ok, opts)
      end

      def init(:ok) do
        send self, {:update, 0}
        {:ok, []}
      end

      def handle_info({:update, id}, state) do
        new_id = Nadia.get_updates([offset: id]) |> process_updates

        :erlang.send_after(100, self, {:update, new_id + 1})
        {:noreply, state}
      end

      def handle_info(_object, state), do: {:noreply, state}

      def process_updates({:ok, []}), do: -1
      def process_updates({:ok, updates}) do
        for update <- updates do
          try do
            update |> process_update
          rescue
            _error -> nil
          end
        end
        List.last(updates).update_id
      end

      def process_updates({:error, error}) do
        case error do
          %Nadia.Model.Error{reason: msg} -> Logger.warn "Nadia: #{msg}"
          error -> Logger.error "Error: #{error}"
        end

        -1
      end
    end
  end

  defmacro handle(:update, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{message: var!(message)} = var!(update)) do
        unquote(body)
      end
    end
  end

  defmacro handle(:edited_message, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{:edited_message => var!(message)} = var!(update)) when var!(message) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:inline_query, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{:inline_query => var!(object), :message => var!(message)} = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:chosen_inline_result, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{:chosen_inline_result => var!(object), :message => var!(message)} = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:callback_query, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{:callback_query => var!(object), :message => var!(message)} = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(type, do: body) do
    quote do
      def process_update(%Nadia.Model.Update{message: %Nadia.Model.Message{unquote(type) => var!(object)} = var!(message)} = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro command(commands, do: function) when is_list(commands) do
    for text <- commands, do: gen_commands(text, do: function)
  end

  defmacro command(text, do: function) do
    gen_commands(text, do: function)
  end

  defmacro match(matches, do: function) when is_list(matches) do
    for text <- matches, do: gen_matches(text, do: function)
  end

  defmacro match(text, do: function) do
    gen_matches(text, do: function)
  end

  defmacro reply(function) do
    quote do
      var!(message).chat.id |> unquote(function)
    end
  end

  defp gen_commands(text, do: function) do
    quote do
      if var!(message) != nil do
        if var!(object) |> String.trim_trailing == "/" <> unquote(text) do
          Task.async(fn -> unquote(function) end)
        end

        if var!(object) |> String.trim_trailing == "/" <> unquote(text) <> "@" <> unquote(@bot_name) do
          Task.async(fn -> unquote(function) end)
        end
      end
    end
  end

  defp gen_matches(text, do: function) do
    quote do
      if var!(message) != nil do
        if var!(object) |> String.trim_trailing == unquote(text) do
          Task.async(fn -> unquote(function) end)
        end
      end
    end
  end
end
