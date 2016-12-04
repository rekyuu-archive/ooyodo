defmodule Ooyodo.Bot do
  use Ooyodo.Module

  handle :inline_query do
    results = [
      %Nadia.Model.InlineQueryResult.Article{
        id: "0",
        title: query,
        input_message_content: %Nadia.Model.InputMessageContent.Text{
          message_text: query,
          parse_mode: "Markdown"
        }
      }
    ]

    reply answer_inline_query(results)
  end

  handle :text do
    command "ping", do: reply send_message "Pong!"

    match ["hi", "hello"], do: reply send_message "Hello!"

    command "start" do
      IO.inspect id
      reply send_message "Pick one!", [
        reply_markup: %Nadia.Model.ReplyKeyboardMarkup{
          keyboard: [
            [%Nadia.Model.KeyboardButton{text: "Heads"},
             %Nadia.Model.KeyboardButton{text: "Tails"}],
            [%Nadia.Model.KeyboardButton{text: "Cancel"}]
          ]
        }
      ]
    end

    match ["Heads", "Tails"] do
      reply send_message "Nice!", [
        reply_markup: %Nadia.Model.ReplyKeyboardHide{}
      ]
    end

    match "Cancel" do
      reply send_message "Alright, cancelled.", [
        reply_markup: %Nadia.Model.ReplyKeyboardHide{}
      ]
    end
  end
end
