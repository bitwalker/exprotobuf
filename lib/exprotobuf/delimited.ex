defmodule Protobuf.Delimited do
  def encode(messages) do
    # loops over messages and encodes them
    # also creates a final byte stream which contains the messages
    # delimited by their bytes size
    # e.g. if input has [m1, m2, m3]
    # output would be << byte_size_of_encoded(m1), encoded(m1), byte_size_of_encoded(m2), encoded(m2), .... >>
    messages
    |> Enum.map(&encode_message/1)
    |> Enum.join
  end

  # the input bytes are laid out as:
  # << 4-bytes-of-byte-size, message, 4-bytes-of-byte-size, message,.... >>
  def decode(bytes, module) do
    do_decode(bytes, module, [])
  end

  defp do_decode(<< number_of_bytes ::  size(32) >> <> << message_bytes :: bytes-size(number_of_bytes), rest :: binary >>, module, acc) do
    decoded_message = apply(module, :decode, [message_bytes])
    do_decode(rest, module, [decoded_message | acc])
  end

  defp do_decode(<<>>, module, acc) do
    acc |> Enum.reverse
  end

  # private stuff
  defp encode_message(message) do
    encoded_bytes = apply(message.__struct__, :encode, [message])
    size = byte_size(encoded_bytes) |> encode_byte_size

    size <> encoded_bytes
  end

  # encodes integer as a 32 bit binary
  defp encode_byte_size(bs) do
    << bs ::  size(32) >>
  end

  defp decode_byte_size(bytes) do
    << bs ::  size(32) >> = bytes
    bs
  end

end
