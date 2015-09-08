#!/usr/bin/env ruby

require "json"
require_relative "errors_reporter"

$errors_dictionary = {
  $error_no_file_argument_given = 1 => "Usage: #{$0} <gzipped json structure>",
  $error_could_not_unzip_file = 2 => "Couldn't unzip input file",
  $error_could_not_parse_json = 3 => "Couldn't parse the decompressed file - expected json",
  $error_no_data_in_json = 4 => "Missing variable in the decompressed json: %s"
}

def fatal(code, *args)
  $stderr.printf $errors_dictionary[code] + "\n", *args
  if code != $error_no_file_argument_given then
    ErrorsReporter.report_error("upload_structure_failure", {"error_code" => code, "args" => args})
  end
  exit code
end

file = ARGV[0]
fatal($error_no_file_argument_given) if file.nil?

json_string = `gunzip -c \"#{file}\"`
fatal($error_could_not_unzip_file) if $?.to_i != 0

begin
  json = JSON.parse(json_string)
rescue
end
fatal $error_could_not_parse_json if json.nil?

vars = ["md5", "env_GCC_PREPROCESSOR_DEFINITIONS__DEBUG", "rollout_appKey", "CFBundleShortVersionString", "CFBundleVersion", "rollout_build"]
curl_args = vars.map() { |var|
  value = json[var]
  fatal $error_no_data_in_json, var if value.nil?
  var + "=" + json[var]
}.join "&"

server_env = ENV["ROLLOUT_allServicesInOneServer"]
server = server_env ? server_env : "https://upload.rollout.io"

curl_cmd = "curl --location --post301 --post302 -F structure=@\"#{file}\" '" + server + "/build/structures?" + curl_args + "'"

system curl_cmd
