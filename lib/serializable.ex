defprotocol Protobuf.Serializable do
  @moduledoc """
  Defines the contract for serializing protobuf messages.
  """

  @doc """
  Serializes the provided object as a protobuf message in binary form.
  """
  def serialize(object)
end
