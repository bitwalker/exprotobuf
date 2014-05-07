defmodule GpbCompileHelper do

  def compile_tmp_proto(msgs) do
    compile_tmp_proto(msgs, nil)
  end

  def compile_tmp_proto(msgs, func) do
    compile_tmp_proto(msgs, [], func)
  end

  def compile_tmp_proto(msgs, options, func) do
    compile_tmp_proto(msgs, options, find_unused_module, func)
  end

  def compile_tmp_proto(msgs, options, module, func) do
    {:ok, defs} = Protobuf.Parser.parse(msgs, options)

    options = [:binary | options]

    {:ok, ^module, module_binary} = :gpb_compile.msg_defs(module, defs, options)
    :code.load_binary(module, '<nofile>', module_binary)

    if func do
      func.(module)
      unload(module)
    else
      module
    end
  end

  def reload do
    Code.unload_files [__ENV__.file]
    Code.require_file __ENV__.file
  end

  def unload(module) do
    :code.purge(module)
    :code.delete(module)
  end

  def find_unused_module(n \\ 1) do
    mod_name_candidate = :'protobuf_test_tmp_#{n}'
    case :code.is_loaded(mod_name_candidate) do
      false -> mod_name_candidate
      {:file, '<nofile>'} -> find_unused_module(n + 1)
    end
  end
end
