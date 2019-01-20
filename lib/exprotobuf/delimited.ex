defmodule Protobuf.Delimited do
  @moduledoc """
  Handles serialization/deserialization of multi-message encoded binaries.
  """

  @doc """
  Loops over messages and encodes them.
  Also creates a final byte stream which contains the messages delimited by their byte size.

  ## Example

      input = [m1, m2, m3]
      output = <<byte_size(encoded_m1), encoded_m1, byte_size(encoded_m2), encoded_m2, ..>>
  """
  @spec encode([map]) :: binary
  def encode(messages) do
    messages
    |> Enum.map(&encode_message/1)
    |> Enum.join
  end

  @doc """
  Decodes one or more messages in a delimited, encoded binary.

  Input binary should have the following layout:

      <<byte_size_m1::size(32), m1::bytes-size(byte_size_m1), ..>>

  Output will be a list of decoded messages, in the order they appear
  in the input binary. If an error occurs, an error tuple will be
  returned.
  """
  @spec decode(binary, atom) :: [map] | {:error, term}
  def decode(bytes, module) do
    do_decode(bytes, module, [])
  end
  defp do_decode(<<num_bytes::size(32), message_bytes::bytes-size(num_bytes), rest::binary>>, module, acc) do
    decoded_message = module.decode(message_bytes)
    do_decode(rest, module, [decoded_message | acc])
  end
  defp do_decode(<<>>, _module, acc) do
    Enum.reverse(acc)
  end
  defp do_decode(rest, _module, _acc) do
    {:error, {:delimited_err, {:invalid_binary, rest}}}
  end

  defp encode_message(%{__struct__: module} = message) do
    encoded_bytes = module.encode(message)
    <<byte_size(encoded_bytes)::size(32), encoded_bytes::binary>>
  end
end
