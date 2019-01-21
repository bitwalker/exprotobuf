defmodule Protobuf.Decoder do
  use Bitwise, only_operators: true
  require Protobuf.Utils, as: Utils
  alias Protobuf.Field
  alias Protobuf.OneOfField

  # Decode with record/module
  def decode(bytes, module) do
    defs =
      for {{type, mod}, fields} <- module.defs, into: [] do
        case type do
          :msg ->
            {{:msg, mod},
             Enum.map(fields, fn field ->
               case field do
                 %Field{} ->
                   Utils.convert_to_record(field, Field)

                 %OneOfField{} ->
                   Utils.convert_to_record(field, OneOfField)
               end
             end)}

          type when type in [:enum, :extensions, :service, :group] ->
            {{type, mod}, fields}
        end
      end

    bytes
    |> :gpb.decode_msg(module, defs)
    |> Utils.convert_from_record(module)
    |> convert_fields()
    |> unwrap_scalars(Utils.msg_defs(module.defs))
  end

  def varint(bytes) do
    :gpb.decode_varint(bytes)
  end

  defp convert_fields(%module{} = msg) do
    converted =
      msg
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reduce(msg, fn
        field, msg ->
          value = Map.get(msg, field)

          if value == :undefined do
            Map.put(msg, field, get_default(module.syntax(), field, module))
          else
            convert_field(value, msg, module.defs(:field, field))
          end
      end)

    struct(module, converted)
  end

  defp get_default(:proto2, field, module) do
    Map.get(struct(module), field)
  end

  defp get_default(:proto3, field, module) do
    case module.defs(:field, field) do
      %OneOfField{} ->
        nil

      x ->
        case x.type do
          :string ->
            ""

          ty ->
            case :gpb.proto3_type_default(ty, module.defs) do
              :undefined ->
                nil

              default ->
                default
            end
        end
    end
  end

  defp convert_field(value, msg, %Field{name: field, type: type, occurrence: occurrence}) do
    case {occurrence, type} do
      {:repeated, _} ->
        value = for v <- value, do: convert_value(type, v)
        Map.put(msg, field, value)

      {_, :string} ->
        Map.put(msg, field, convert_value(type, value))

      {_, {:msg, _}} ->
        Map.put(msg, field, convert_value(type, value))

      _ ->
        msg
    end
  end

  defp convert_field({key, inner_value} = value, msg, %OneOfField{name: field}) do
    cond do
      is_tuple(inner_value) ->
        module = elem(inner_value, 0)

        converted_value =
          inner_value
          |> Utils.convert_from_record(module)
          |> convert_fields()

        Map.put(msg, field, {key, converted_value})

      is_list(inner_value) ->
        Map.put(msg, field, {key, convert_value(:string, inner_value)})

      true ->
        Map.put(msg, field, value)
    end
  end

  defp convert_value(:string, value),
    do: :unicode.characters_to_binary(value)

  defp convert_value({:msg, _}, value) do
    value
    |> Utils.convert_from_record(elem(value, 0))
    |> convert_fields()
  end

  defp convert_value({:map, key_type, value_type}, {key, value}),
    do: {convert_value(key_type, key), convert_value(value_type, value)}

  defp convert_value(_, value),
    do: value

  defp unwrap_scalars(%msg_module{} = msg, %{} = defs) do
    msg
    |> Map.from_struct()
    |> Enum.reduce(msg, fn
      # nil is unwrapped
      {_, nil}, acc ->
        acc

      # recursive unwrap repeated
      {k, v}, acc when is_list(v) ->
        Map.put(acc, k, Enum.map(v, &unwrap_scalars(&1, defs)))

      # unwrap messages
      {k, {oneof, %_{} = v}}, acc when is_atom(oneof) ->
        Map.put(acc, k, {oneof, do_unwrap(v, [msg_module, k, oneof], defs)})

      {k, %_{} = v}, acc ->
        Map.put(acc, k, do_unwrap(v, [msg_module, k], defs))

      # scalars are unwrapped
      {_, {oneof, v}}, acc when is_atom(oneof) and Utils.is_scalar(v) ->
        acc

      {_, v}, acc when Utils.is_scalar(v) ->
        acc
    end)
  end

  defp unwrap_scalars(v, %{}), do: v

  defp do_unwrap(v = %_{}, keys = [_ | _], defs = %{}) do
    %Field{type: {:msg, module}} = get_in(defs, keys)

    if Utils.is_standard_scalar_wrapper(module) do
      v.value
    else
      do_unwrap_enum(v, module, defs)
    end
  end

  defp do_unwrap_enum(v = %_{}, module, defs = %{}) do
    case Enum.to_list(Map.get(defs, module)) do
      [value: %Field{type: {:enum, enum_module}}] ->
        if Utils.is_enum_wrapper(module, enum_module) do
          v.value
        else
          # recursive unwrap nested messages
          unwrap_scalars(v, defs)
        end

      _ ->
        # recursive unwrap nested messages
        unwrap_scalars(v, defs)
    end
  end
end
