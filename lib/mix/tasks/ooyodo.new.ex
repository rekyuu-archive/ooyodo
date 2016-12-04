defmodule Mix.Tasks.Ooyodo.New do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Ooyodo Telegram Bot"

  @switches [app: :string, module: :string, token: :string, bot: :string]

  @spec run(OptionParser.argv) :: :ok
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] -> Mix.raise "Expected PATH to be given, please use \"mix new PATH\""
      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !opts[:app])

        mod = opts[:module] || Macro.camelize(app)
        check_mod_name_validity!(mod)
        check_mod_name_availability!(mod)

        bot = opts[:bot] || Path.basename(Path.expand(path))
        token = opts[:token] || nil

        unless path == "." do
          check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd! path, fn -> generate(app, mod, path, token, bot) end
    end
  end

  defp generate(app, mod, path, token, bot) do
    assigns = [app: app, mod: mod, token: token, bot: bot, version: get_version(System.version)]

    create_file "README.md", readme_template(assigns)
    create_file ".gitignore", gitignore_text()
    create_file "mix.exs", mix_template(assigns)

    create_directory "config"
    create_file "config/config.exs", config_template(assigns)
    create_file "config/secret.exs", secret_template(assigns)

    create_directory "lib"
    create_file "lib/#{app}.ex", lib_template(assigns)
    create_file "lib/bot.ex", bot_template(assigns)

    create_directory "lib/#{app}"
    create_file "lib/#{app}/module.ex", module_template(assigns)

    create_directory "lib/mix/tasks"
    create_file "lib/mix/tasks/#{app}.ex", mix_tasks_template(assigns)

    create_directory "test"
    create_file "test/test_helper.exs", test_helper_template(assigns)
    create_file "test/#{app}_test.exs", app_test_template(assigns)

    """
    Your Ooyodo Telegram Bot project was created successfully!
    To run your bot:

        $ cd #{path}
        $ mix deps.get
        $ mix #{app}

    Have fun!
    """
    |> String.trim_trailing
    |> Mix.shell.info
  end

  defp check_application_name!(name, inferred?) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      "Application name must start with a letter and have only lowercase " <>
      "letters, numbers and underscore, got: #{inspect name}" <>
      (if inferred? do
      ". The application name is inferred from the path, if you'd like to " <>
      "explicitly name the application then use the \"--app APP\" option"
      else
      ""
      end)
      |> Mix.raise
    end
  end

  defp check_mod_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_mod_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp check_directory_existence!(path) do
    if File.dir?(path) and not Mix.shell.yes?("The directory #{inspect(path)} already exists. Are you sure you want to continue?") do
      Mix.raise "Please select another directory for installation"
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)
    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        []      -> ""
      end
  end

  embed_template :readme, """
  # <%= @mod %> Telegram Bot

  A bot wrapper for [Nadia](https://github.com/zhyu/nadia).

  ## Quick Start

  To get started, [download the latest release](https://github.com/rekyuu/ooyodo/releases) and install the archive with mix:

  ```
  $ mix archive.install Ooyodo.New.ez
  ```

  Then create a new project:

  ```
  $ mix ooyodo.new appname --token your_api_token
  ```

  Then to run:

  ```
  $ cd appname
  $ mix deps.get
  $ mix appname
  ```

  ## Development

  Tested update types:

  [x] Messages
  [x] Inline queries
  [x] Edited messages
  [ ] Chosen inline results
  [ ] Callback queries
  """

  embed_text :gitignore, """
  # The directory Mix will write compiled artifacts to.
  /_build

  # If you run "mix test --cover", coverage assets end up here.
  /cover

  # The directory Mix downloads your dependencies sources to.
  /deps

  # Where 3rd-party dependencies like ExDoc output generated docs.
  /doc

  # If the VM crashes, it generates a dump, let's ignore it too.
  erl_crash.dump

  # Also ignore archive artifacts (built via "mix archive.build").
  *.ez
  mix.lock
  """

  embed_template :mix, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project

    def project do
      [app: :<%= @app %>,
       version: "0.1.1",
       elixir: "~> <%= @version %>",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       deps: deps()]
    end

    # Configuration for the OTP application
    #
    # Type "mix help compile.app" for more information
    def application do
      [applications: [:logger, :nadia],
       mod: {<%= @mod %>, []}]
    end

    # Dependencies can be Hex packages:
    #
    #   {:mydep, "~> 0.3.0"}
    #
    # Or git/path repositories:
    #
    #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
    #
    # Type "mix help deps" for more examples and options
    defp deps do
      [{:nadia, git: "https://github.com/zhyu/nadia"}]
    end
  end
  """

  embed_template :config, """
  use Mix.Config

  config :<%= @app %>,
    username: "<%= @bot %>"

  import_config "secret.exs"
  """

  embed_template :secret, """
  use Mix.Config

  config :nadia,
    token: "<%= @token %>"
  """

  embed_template :lib, """
  defmodule <%= @mod %> do
    def start(_type, _args) do
      import Supervisor.Spec
      children = [supervisor(<%= @mod %>.Bot, [[name: <%= @mod %>.Bot]])]
      {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
    end
  end
  """

  embed_template :bot, """
  defmodule <%= @mod %>.Bot do
    use <%= @mod %>.Module

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
  """

  embed_template :module, """
  defmodule <%= @mod %>.Module do
    @bot_name Application.get_env(:<%= @app %>, :username)

    defmacro __using__(_options) do
      quote do
        import <%= @mod %>.Module
        import Nadia
        require Logger
        use GenServer

        def start_link(opts \\\\ []) do
          Logger.debug "Starting bot!"
          GenServer.start_link(__MODULE__, :ok, opts)
        end

        def init(:ok) do
          send self, {:update, 0}
          {:ok, []}
        end

        def handle_info({:update, id}, state) do
          new_id = get_updates([offset: id]) |> process_updates

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
            %Nadia.Model.Error{reason: msg} -> Logger.warn "Nadia: \#{msg}"
            error -> Logger.error "Error: \#{error}"
          end

          -1
        end
      end
    end

    defmacro handle(:edited_message, do: body) do
      quote do
        def process_update(
          %Nadia.Model.Update{
            edited_message: var!(message)
          } = var!(update)) when var!(message) != nil do
          unquote(body)
        end
      end
    end

    defmacro handle(:inline_query, do: body) do
      quote do
        def process_update(
          %Nadia.Model.Update{
            inline_query: %{
              query: var!(query),
              id: var!(id)
            } = var!(object)
          } = var!(update)) when var!(object) != nil do
          unquote(body)
        end
      end
    end

    defmacro handle(:chosen_inline_result, do: body) do
      quote do
        def process_update(
          %Nadia.Model.Update{
            chosen_inline_result: var!(object),
            message: var!(message)
          } = var!(update)) when var!(object) != nil do
          unquote(body)
        end
      end
    end

    defmacro handle(:callback_query, do: body) do
      quote do
        def process_update(
          %Nadia.Model.Update{
            callback_query: var!(object),
            message: var!(message)
          } = var!(update)) when var!(object) != nil do
          unquote(body)
        end
      end
    end

    defmacro handle(type, do: body) do
      quote do
        def process_update(
          %Nadia.Model.Update{
            message: %Nadia.Model.Message{
              unquote(type) => var!(object),
              chat: %{id: var!(id)}
            } = var!(message)
          } = var!(update)) when var!(object) != nil do
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
        var!(id) |> unquote(function)
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
  """

  embed_template :mix_tasks, """
  defmodule Mix.Tasks.<%= @mod %> do
    use Mix.Task

    @shortdoc "Runs your <%= @mod %> Telegram Bot"

    def run(args), do: Mix.Task.run "run", run_args ++ args

    defp run_args, do: if iex_running?(), do: [], else: ["--no-halt"]
    defp iex_running?, do: Code.ensure_loaded?(IEx) and IEx.started?
  end
  """

  embed_template :test_helper, """
  ExUnit.start()
  """

  embed_template :app_test, """
  defmodule <%= @mod %>Test do
    use ExUnit.Case
    doctest <%= @mod %>

    test "the truth" do
      assert 1 + 1 == 2
    end
  end
  """
end
