defmodule Protobuf.Decoder do
  use Bitwise, only_operators: true
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Utils

  # Decode with record/module
  def decode(bytes, module) do
    defs = for {{type, mod}, fields} <- module.defs, into: [] do
      case type do
        :msg ->
          {{:msg, mod}, Enum.map(fields, fn field ->
            case field do
              %Field{}      -> Utils.convert_to_record(field, Field)
              %OneOfField{} -> Utils.convert_to_record(field, OneOfField)
            end
          end)}
        type when type in [:enum, :extensions, :service, :group] ->
          {{type, mod}, fields}
      end
    end
    :gpb.decode_msg(bytes, module, defs)
    |> Utils.convert_from_record(module)
    |> convert_fields
    |> unwrap_scalars(module.defs |> Utils.msg_defs)
  end

  def varint(bytes) do
    :gpb.decode_varint(bytes)
  end

  defp convert_fields(msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      :__struct__, msg -> msg
      field, %{__struct__: module} = msg ->
        value = Map.get(msg, field)
        if value == :undefined do
          Map.put(msg, field, get_default(module.syntax(), field, module))
        else
          convert_field(value, msg, module.defs(:field, field))
        end
    end)
  end

  defp get_default(:proto2, field, module) do
    Map.get(struct(module), field)
  end
  defp get_default(:proto3, field, module) do
    case module.defs(:field, field) do
      %Protobuf.OneOfField{} -> nil
      x ->
        case x.type do
          :string ->
            ""
          ty ->
            case :gpb.proto3_type_default(ty, module.defs) do
              :undefined -> nil
              default -> default
            end
        end
    end
  end

  defp convert_field(value, msg, %Field{name: field, type: type, occurrence: occurrence}) do
    case {occurrence, type} do
      {:repeated, _} ->
        value = for v <- value, do: convert_value(type, v)
        Map.put(msg, field, value)
      {_, :string}   ->
        Map.put(msg, field, convert_value(type, value))
      {_, {:msg, _}} ->
        Map.put(msg, field, convert_value(type, value))
      _ ->
        msg
    end
  end

  defp convert_field(value, msg, %OneOfField{name: field}) do
    {key, inner_value} = value
    cond do
      is_tuple(inner_value) ->
        module = elem(inner_value, 0)
        converted_value = {key, inner_value |> Utils.convert_from_record(module) |> convert_fields}
        Map.put(msg, field, converted_value)
      is_list(inner_value) ->
        Map.put(msg, field, {key, convert_value(:string, inner_value)})
      true ->
        Map.put(msg, field, value)
    end
  end

  defp convert_value(:string, value),
    do: :unicode.characters_to_binary(value)
  defp convert_value({:msg, _}, value),
    do: value |> Utils.convert_from_record(elem(value, 0)) |> convert_fields
  defp convert_value({:map, key_type, value_type}, {key, value}),
    do: {convert_value(key_type, key), convert_value(value_type, value)}
  defp convert_value(_, value),
    do: value

  defp unwrap_scalars(%msg_module{} = msg, %{} = defs) do
    msg
    |> Map.from_struct
    |> Enum.reduce(msg, fn
      # nil is unwrapped
      {_, nil}, acc = %_{} ->
        acc
      # recursive unwrap repeated
      {k, v}, acc = %_{} when is_list(v) ->
        Map.put(acc, k, Enum.map(v, &(unwrap_scalars(&1, defs))))
      # unwrap scalars and messages
      {k, {oneof, v}}, acc = %_{} ->
        Map.put(acc, k, {oneof, do_unwrap(v, [msg_module, k, oneof], defs)})
      {k, v}, acc = %_{} ->
        Map.put(acc, k, do_unwrap(v, [msg_module, k], defs))
    end)
  end
  defp unwrap_scalars(v, %{}), do: v

  defp do_unwrap(v, keys = [_ | _], defs = %{}) do
    defs
    |> get_in(keys)
    |> case do
      %Protobuf.Field{type: scalar} when is_atom(scalar) ->
        v
      %Protobuf.Field{type: {:enum, module}} when is_atom(module) ->
        v
      %Protobuf.Field{type: {:msg, module}} when is_atom(module) ->
        Utils.standard_scalar_wrappers
        |> MapSet.member?(module |> Module.split |> Stream.take(-3) |> Enum.join("."))
        |> case do
          true ->
            %_{value: value} = v
            value
          false ->
            do_unwrap_enum(v, module, defs)
        end
    end
  end

  defp do_unwrap_enum(v, module, defs = %{}) do
    defs
    |> Map.get(module)
    |> Enum.to_list
    |> case do
      [value: %Field{type: {:enum, enum_module}}] ->
        module
        |> to_string
        |> Kernel.==("#{enum_module}Value")
        |> case do
          true ->
            %_{value: value} = v
            value
          false ->
            #
            # TODO : check safety of this recursive call
            #
            # recursive unwrap nested messages
            unwrap_scalars(v, defs)
        end
      _ ->
        #
        # TODO : check safety of this recursive call
        #
        # recursive unwrap nested messages
        unwrap_scalars(v, defs)
    end
  end

end
