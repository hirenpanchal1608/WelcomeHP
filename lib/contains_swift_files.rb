#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/xcodeproj-0.14.1/ext"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/xcodeproj-0.14.1/lib"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/colored-1.2/lib"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/activesupport-3.2.17/lib"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/multi_json-1.9.2/lib"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/i18n-0.6.9/lib"
$:.unshift File.dirname(__FILE__) + "/vendor/bundle/ruby/2.0.0/gems/rake-10.2.2/lib"
require_relative 'vendor/bundle/ruby/2.0.0/gems/xcodeproj-0.14.1/lib/xcodeproj'


def init_project(dir)
  project = Xcodeproj::Project.new(dir)
  project.initialize_from_file
  project
end

def get_target(project, target_name)
  target = project.objects.select { |o|
    o.isa == "PBXNativeTarget" && o.name == target_name
  }
  target[0]
end

project = init_project(ARGV[0])
target = get_target(project, ARGV[1])
if !target
  $stderr.write "Didn't find target #{ARGV[1]}\n"
  exit 1
end

target.build_phases.each { |phase| 
  phase.files.select { |build_file| 
    if (!build_file.file_ref.nil?) && build_file.file_ref.isa != "PBXReferenceProxy" && build_file.file_ref.respond_to?("last_known_file_type") && build_file.file_ref.last_known_file_type == "sourcecode.swift" 
      exit 0
    end
  }
}

exit 2
