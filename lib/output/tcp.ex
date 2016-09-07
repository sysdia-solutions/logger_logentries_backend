defmodule Logger.Backend.Logentries.Output.Tcp do
  def open(host, port) do
    :gen_tcp.connect(host, port, [:binary, active: false])
  end

  def transmit(socket, message) do
    :gen_tcp.send(socket, message)
  end
end
