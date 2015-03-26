#!/usr/bin/env ruby

require 'json'

$src = JSON.parse(STDIN.read)
static_json_filename = ARGV[0]
static_json = static_json_filename.nil? ? {} : JSON.parse(IO.read(ARGV[0]))
clazzes = static_json

$kinds_map = {
  "Long long int" => "LongLong",
  "Long int" => "Long",
  "Unsigned int" => "UInt",
  "Signed char" => "SChar",
  "Long unsigned int" => "ULong",
  "Unsigned short" => "UShort",
  "Long long unsigned int" => "ULongLong",
  "Long double" => "LongDouble",
  "_Bool" => "Bool",
  "Char" => "Char_S",
  "Unsigned char" => "UChar"
}

$origins_map = {
  "long long int" => "long long",
  "long int" => "long",
  "long unsigned int" => "unsigned long",
  "long long unsigned int" => "unsigned long long"
}

$types_map = {
  "long long int" => "long long",
  "long int" => "long",
  "long unsigned int" => "unsigned long",
  "long long unsigned int" => "unsigned long long"
}

def get_converted_type(type)
  $types_map[type].nil? ? type : $types_map[type]
end
def get_converted_origin(origin)
  $origins_map[origin].nil? ? origin : $origins_map[origin]
end
def get_converted_kind(kind)
  $kinds_map[kind].nil? ? kind : $kinds_map[kind]
end
def build_arg_hirarchy (ref)
  arg = $src["types"][ref]
  arg["address"] = ref unless arg.nil? or ref.nil?
  if ref
    return [arg] + build_arg_hirarchy(arg["ref"]) 
  end
  return [arg]
end

def get_type_from_hirarchy(hirarchy)
  arg = hirarchy.first
  if (arg.nil?)
    return {}
  end
  result = get_type_from_hirarchy(hirarchy.slice(1..-1))
  symbol = arg["symbol"]
  case arg["tag"]
  when "DW_TAG_enumeration_type"
    result["kind"] = "Enum"
    result["type"] = "enum " + symbol unless symbol.nil?
    result["size"] = arg["size"]
    result["origin"] = "enum " + symbol unless symbol.nil?
  when "DW_TAG_structure_type"
    result["size"] = arg["size"]
    if arg["appleRuntime"] == 1 or symbol == "objc_object"
      result["type"] = symbol
      result["origin"] = symbol
      result["kind"] = "ObjCObject"
    elsif symbol == "__block_literal_generic"
      result["type"] = symbol
      result["origin"] = symbol
      result["kind"] = "Block"
    else
      result["kind"] = "Record"
      result["record_data_ref"] = arg["address"]
      result["type"] = "struct " + symbol unless symbol.nil?
      result["origin"] = "struct " + symbol unless symbol.nil?
    end
   when "DW_TAG_base_type"
    capitalize_symbol = symbol.empty? ? symbol : symbol.slice(0,1).capitalize + symbol.slice(1..-1) 
    result["kind"] = get_converted_kind(capitalize_symbol)  
    result["type"] = get_converted_type(symbol)
    result["size"] = arg["size"]
    result["origin"] = get_converted_origin(symbol)
  when "DW_TAG_pointer_type"
    result["type"] = "void" if result["type"].nil?
    result["origin"] = "void" if result["origin"].nil?
    result["type"] += result["kind"] == "Pointer" ? "*" : " *" 
    result["origin"] += result["kind"] == "Pointer" ? "*" : " *"  
    result.delete("size")
    if result["kind"] =="ObjCObject" || result["kind"] == "Block"
      result["kind"] += "Pointer"  
    elsif result["kind"] == "CONST"
      result["kind"] = "Pointer"
      result["type"] = "const void *"
      result["origin"] = "const void *"
    else 
      result["kind"] = "Pointer"
    end 
  when "DW_TAG_typedef" 
    result["origin"] = symbol
    result["type"] = symbol if result["type"].nil?
    if symbol == "id"
      result["origin"] = "id"
      result["type"] = "id"
      result["kind"] = "ObjCObjectPointer"
    end
  when "DW_TAG_const_type"
    if result["kind"] == "Pointer"
      result["origin"] = result["origin"]  + "const"
      result["type"] = result["type"] + "const"
    else
      result["kind"] = "CONST" if result["kind"].nil?
      result["origin"] = "const " + result["origin"] unless result["origin"].nil? 
      result["type"] = "const " + result["type"] unless result["type"].nil? 
    end
  when nil 
  end
#  result["d1_#{hirarchy.size}"] =  "#{arg["tag"]}:#{arg["symbol"]}:#{arg["appleRuntime"]}"
  result
end

$record_types = {}
$resolve_type_caching = {}
def resolve_type (arg) 
  if arg.empty?
    return  {
      "kind" => "Void",
      "origin" => "void",
      "size" => "-2",
      "type" => "void"
    }
  end
  ref = arg["ref"]
  return $resolve_type_caching[ref] if $resolve_type_caching[ref]
  result = get_type_from_hirarchy(build_arg_hirarchy(ref))
  if result["kind"] == "Record"
    $record_types[result["record_data_ref"]] = { "status" => "missing", "origin" => result["origin"]}
  end
  $resolve_type_caching[ref] = result
  return result
end

$resolve_arg = lambda { |arg|
  result = resolve_type(arg).clone
  result["symbol"] = arg["symbol"] unless arg["symbol"].nil?
  result
}
def build_record(record_address, name)
  arg = $src["types"][record_address]
  result = {
    name:  "__rollout_dummy_struct_#{name.gsub(" ", "_rollout_space_")}_#{arg["size"]}_#{record_address}"
  }
  result["children"] = arg["children"].map &$resolve_arg
  return result;
end

$src["methods"].each do |compile_unit|
  compile_unit["children"].delete_if { |method| method["args"].any? { |arg| arg["symbol"] == "_cmd" } }
  compile_unit["children"].each do |method| 
    method["args"].map! &$resolve_arg
    method["return"] = $resolve_arg.call(method["return"])
  end
  compile_unit["children"].each do |method_src|
    clazz_key = method_src["class"]
    clazz = clazzes[clazz_key]
    if clazz.nil?
      clazz = {
        "kind" => compile_unit["kind"],
        "symbol" => clazz_key,
        "children" => []
      }
      clazzes[clazz_key] = clazz
    end
    method = {}
    clazz["children"].push method
    method["kind"] = method_src["kind"]
    method["file"] = compile_unit["symbol"]
    method["line"] = method_src["line"]
    method["symbol"] = method_src["symbol"]
    method["args"] = method_src["args"]
    method["return"] = method_src["return"]
  end
end
while not ($record_types.values.find { |record| record["status"] == "missing" }).nil? 
  $record_types.keys.each do |record_address|
    $record_types[record_address] = build_record(record_address, $record_types[record_address]["origin"]) if $record_types[record_address]["status"] == "missing"
  end
end

puts JSON.generate({ "structs" => $record_types, "methods" => clazzes.values})
