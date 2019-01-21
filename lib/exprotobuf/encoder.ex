defmodule Protobuf.Encoder do
  require Protobuf.Utils, as: Utils
  alias Protobuf.Field
  alias Protobuf.OneOfField

  def encode(%{} = msg, defs) do
    fixed_defs =
      for {{type, mod}, fields} <- defs, into: [] do
        case type do
          :msg ->
            {{:msg, mod},
             Enum.map(fields, fn field ->
               case field do
                 %OneOfField{} ->
                   Utils.convert_to_record(field, OneOfField)

                 %Field{} ->
                   Utils.convert_to_record(field, Field)
               end
             end)}

          type when type in [:enum, :extensions, :service, :group] ->
            {{type, mod}, fields}
        end
      end

    msg
    |> wrap_scalars(Utils.msg_defs(defs))
    |> fix_undefined
    |> Utils.convert_to_record(msg.__struct__)
    |> :gpb.encode_msg(fixed_defs)
  end

  defp fix_undefined(%{} = msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      field, msg ->
        original = Map.get(msg, field)
        fixed = fix_value(original)

        if original != fixed do
          Map.put(msg, field, fixed)
        else
          msg
        end
    end)
  end

  defp fix_value(nil), do: :undefined

  defp fix_value(values) when is_list(values),
    do: Enum.map(values, &fix_value/1)

  defp fix_value(%module{} = value) do
    value
    |> fix_undefined()
    |> Utils.convert_to_record(module)
  end

  defp fix_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&fix_value/1)
    |> List.to_tuple()
  end

  defp fix_value(value), do: value

  defp wrap_scalars(%msg_module{} = msg, %{} = defs) do
    msg
    |> Map.from_struct()
    |> Enum.reduce(msg, fn
      # nil is unwrapped
      {_, nil}, acc = %_{} ->
        acc

      # recursive wrap repeated
      {k, v}, acc = %_{} when is_list(v) ->
        Map.put(acc, k, Enum.map(v, &wrap_scalars(&1, defs)))

      # recursive wrap message
      {k, {oneof, v = %_{}}}, acc = %_{} when is_atom(oneof) ->
        Map.put(acc, k, {oneof, wrap_scalars(v, defs)})

      {k, v = %_{}}, acc = %_{} ->
        Map.put(acc, k, wrap_scalars(v, defs))

      # plain wrap scalar
      {k, {oneof, v}}, acc = %_{} when is_atom(oneof) and Utils.is_scalar(v) ->
        Map.put(acc, k, {oneof, do_wrap(v, [msg_module, k, oneof], defs)})

      {k, v}, acc = %_{} when Utils.is_scalar(v) ->
        Map.put(acc, k, do_wrap(v, [msg_module, k], defs))
    end)
  end

  defp wrap_scalars(v, %{}), do: v

  defp do_wrap(v, keys = [_ | _], defs = %{}) do
    case get_in(defs, keys) do
      %Field{type: scalar} when is_atom(scalar) ->
        v

      %Field{type: {:enum, module}} when is_atom(module) ->
        v

      %Field{type: {:msg, module}} when is_atom(module) ->
        if Utils.is_standard_scalar_wrapper(module) do
          Map.put(module.new, :value, v)
        else
          do_wrap_enum(v, module, defs)
        end
    end
  end

  defp do_wrap_enum(v, module, defs = %{}) do
    case Enum.to_list(Map.get(defs, module)) do
      [value: %Field{type: {:enum, enum_module}}] ->
        if Utils.is_enum_wrapper(module, enum_module) do
          Map.put(module.new, :value, v)
        else
          v
        end

      _ ->
        v
    end
  end
end
