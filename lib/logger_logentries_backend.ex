defmodule Logger.Backend.Logentries do
  use GenEvent

  require Logger

  @default_format "[$level] $message\n"

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_call(:connector, %{connector: connector} = state) do
    {:ok, {:ok, connector}, state}
  end

  def handle_call(:remove_connection, %{name: name} = state) do
    {:ok, :ok, %{state | connection: nil}}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, metadata_filter: metadata_filter} = state) do
    state = if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) and metadata_matches?(md, metadata_filter) do
      open_connection_and_log_event(state, level, msg, ts, md, true)
    else
      state
    end
    {:ok, state}
  end

  def open_connection_and_log_event(%{connection: connection} = state, level, msg, ts, md, _retry) when not is_nil(connection) do
    log_event(level, msg, ts, md, state)
  end

  def open_connection_and_log_event(%{connection: connection} = state, level, msg, ts, md, retry) when is_nil(connection) and retry == true do
    open_connection(state) |> open_connection_and_log_event(level, msg, ts, md, false)
  end

  def open_connection_and_log_event(%{connection: connection} = state, level, msg, ts, md, retry) when is_nil(connection) and retry == false do
    Logger.error("connection to logentries is not open")
    state
  end

  defp log_event(level, msg, ts, md, %{connector: connector, connection: connection, token: token} = state) do
    log_entry = format_event(level, "#{token} #{msg}", ts, md, state)
    connector.transmit(connection, log_entry)
    state
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: keys}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end

  def metadata_matches?(_md, nil), do: true
  def metadata_matches?(_md, []), do: true
  def metadata_matches?(md, [{key, val} | rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} ->
        metadata_matches?(md, rest)
      _ -> false
    end
  end

  defp take_metadata(metadata, keys) do
    Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end) |> Enum.reverse()
  end

  defp configure(name, opts) do
    state = %{
      name: nil,
      connector: nil,
      host: nil,
      port: nil,
      level: nil,
      format: nil,
      metadata: nil,
      token: nil,
      connection: nil,
      metadata_filter: nil
    }
    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    connector = Keyword.get(opts, :connector, Logger.Backend.Logentries.Output.Tcp)
    host = Keyword.get(opts, :host, 'data.logentries.com')
    port = Keyword.get(opts, :port, 80)
    level = Keyword.get(opts, :level, :debug)
    metadata = Keyword.get(opts, :metadata, [])
    format = Keyword.get(opts, :format, @default_format) |> Logger.Formatter.compile
    token = Keyword.get(opts, :token, "")
    metadata_filter = Keyword.get(opts, :metadata_filter)

    %{
      state |
      name: name,
      connector: connector,
      host: host,
      port: port,
      level: level,
      format: format,
      metadata: metadata,
      token: token,
      metadata_filter: metadata_filter
    }
  end

  def open_connection(%{connector: connector, host: host, port: port} = state) do
    case connector.open(host, port) do
      {:ok, connection} ->
        %{state | connection: connection}
      {:error, reason} ->
        Logger.error("error opening logentries connection: #{inspect reason}")
        %{state | connection: nil}
    end
  end
end
