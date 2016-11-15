defmodule Output.Test do
  @logfile "test_log.log"

  def open(_host, _port) do
    File.open(@logfile, [:write])
  end

  def transmit(file, message) do
    IO.write(file, message)
  end

  def read() do
    if exists() do
      File.read!(@logfile)
    end
  end

  def exists() do
    File.exists?(@logfile)
  end

  def destroy() do
    if exists() do
      File.rm!(@logfile)
    end
  end
end

defmodule Logger.Backend.Logentries.Test do
  use ExUnit.Case, async: false
  require Logger

  @backend {Logger.Backend.Logentries, :test}
  Logger.add_backend @backend

  setup do
    config([
      connector: Output.Test,
      host: 'logentries.url',
      port: 10000,
      format: "[$level] $message\n",
      token: "<<logentries-token>>",
      metadata_filter: []
    ])
    on_exit fn ->
      connector.destroy()
      remove_connection()
    end
    :ok
  end

  test "default logger level is `:debug`" do
    assert Logger.level() == :debug
  end

  test "does not log when level is under minimum Logger level" do
    config(level: :info)
    Logger.debug("do not log me")
    refute connector().exists()
  end

  test "does log when level is above or equal minimum Logger level" do
    refute connector().exists()
    config(level: :info)
    Logger.warn("you will log me")
    assert connector().exists()
    assert read_log() == "[warn] <<logentries-token>> you will log me\n"
  end

  test "can configure format" do
    config format: "$message ($level)\n"

    Logger.info("I am formatted")
    assert read_log() == "<<logentries-token>> I am formatted (info)\n"
  end

  test "it doesn't log metadata if configured but not set" do
    config format: "$metadata$message\n", metadata: [:user_id, :auth]

    Logger.info("hello")
    assert read_log() == "<<logentries-token>> hello\n"
  end

  test "can configure metadata" do
    config format: "$metadata$message\n", metadata: [:user_id, :auth]
    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.info("hello")
    assert read_log() == "user_id=13 auth=true <<logentries-token>> hello\n"
  end

  test "can configure metadata_filter" do
    config format: "$message\n", metadata_filter: [test: true]
    Logger.info("hello", test: true)
    assert read_log() == "<<logentries-token>> hello\n"
  end

  test "can exclude messages with metadata_filter" do
    config format: "$message\n", metadata_filter: [test: true]
    Logger.info("a", test: true)
    Logger.info("b")
    Logger.info("c", test: false)
    Logger.info("d", test: true)
    assert read_log() == "<<logentries-token>> a\n<<logentries-token>> d\n"
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end

  defp connector() do
    {:ok, connector} = GenEvent.call(Logger, @backend, :connector)
    connector
  end

  defp read_log() do
    connector().read()
  end

  defp remove_connection() do
    :ok = GenEvent.call(Logger, @backend, :remove_connection)
  end
end
