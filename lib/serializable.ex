defprotocol Protobuf.Serializable do
  @moduledoc """
  Defines the contract for serializing protobuf messages.
  """
  @fallback_to_any true

  @doc """
  Serializes the provided object as a protobuf message in binary form.
  """
  def serialize(object)
end

defimpl Protobuf.Serializable, for: Any do
  def serialize(%{__struct__: module} = obj), do: module.encode(obj)
  def serialize(_), do: {:error, :not_serializable}
end
