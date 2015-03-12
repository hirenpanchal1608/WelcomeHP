#!/usr/bin/env ruby

require 'json'

src = JSON.parse(STDIN.read)
static_json_filename = ARGV[0]
static_json = static_json_filename.nil? ? {} : JSON.parse(IO.read(ARGV[0]))
clazzes = static_json

kinds_map = {
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

origins_map = {
  "long long int" => "long long",
  "long int" => "long",
  "long unsigned int" => "unsigned long",
  "long long unsigned int" => "unsigned long long"
}

types_map = {
  "long long int" => "long long",
  "long int" => "long",
  "long unsigned int" => "unsigned long",
  "long long unsigned int" => "unsigned long long"
}

src.each do |compile_unit|
  compile_unit["children"].delete_if { |method| method["args"].any? { |arg| arg["symbol"] == "_cmd" } }

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

    if method["return"] == "(null)" then
      method["return"] = {
        "file" => "(null)",
        "kind" => "Void",
        "line" => 0,
        "origin" => "void",
        "size" => "-2",
        "type" => "void"
      }
    end

    (method["args"] + [method["return"]]).each { |arg|
      converted_kind = kinds_map[arg["kind"]];
      arg["kind"] = converted_kind unless converted_kind.nil?

      converted_type = types_map[arg["type"]];
      arg["type"] = converted_type unless converted_type.nil?

      converted_origin = origins_map[arg["origin"]];
      arg["origin"] = converted_origin unless converted_origin.nil?
    }
  end


end

puts JSON.generate [clazzes.values]
