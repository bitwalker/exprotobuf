defmodule Protobuf.Encoder do
  alias Protobuf.Utils
  alias Protobuf.Field
  alias Protobuf.OneOfField

  def encode(%{} = msg, module) do
    msg
    |> fix_undefined(module)
    |> Utils.convert_to_record(msg.__struct__)
    |> module.erl_module.encode_msg
  end

  defp fix_undefined(%{} = msg, module) do
    Enum.reduce(Map.keys(msg), msg, fn
      field, msg ->
        value = Map.get(msg, field)
        if should_be_fixed?(value) do
          fixed_value = Utils.get_default(module.syntax(), field, module)
          Map.put(msg, field, fixed_value)
        else
          msg
        end
    end)
  end

  def should_be_fixed?(nil), do: true
  def should_be_fixed?(_), do: false
end
