#!/usr/bin/env ruby
require_relative './bundle/bundler/setup'

require 'xcodeproj'

class RemoveRolloutFromXcodeproj
  def initialize(initialized_project)
    @project = initialized_project
  end

  def remove_rollout_from_xcodeproj
    rollout_group = @project.objects.find { |o| o.isa == "PBXGroup" && (o.path == "Rollout" || o.name == "Rollout") }
    files_references = rollout_group ? rollout_group.children.select{|c| c.is_a? Xcodeproj::Project::PBXFileReference} : []
    titles_of_phases_to_remove = ["Rollout.io post-build", "Rollout.io pre-build", "Rollout Code analyzer"]
    
    @project.targets.each do |target|
      if target.respond_to?("product_type") and target.product_type == "com.apple.product-type.application"
        files_references.each do |file_reference|
	  begin
            target.frameworks_build_phase.remove_file_reference file_reference
            target.source_build_phase.remove_file_reference file_reference
	  rescue
	    STDERR.puts "failed to remove #{file_reference} with exception #{$!}"
	  end
      
          target.build_configurations.each do |build_configuration|
            framework_search_path = build_configuration.build_settings["FRAMEWORK_SEARCH_PATHS"]
            if ! framework_search_path.nil?
              framework_search_path = [framework_search_path] if framework_search_path.is_a? String
              build_configuration.build_settings["FRAMEWORK_SEARCH_PATHS"] = framework_search_path.select { |path|
                /Rollout-ios-SDK/.match(path).nil?
              }
            end
          end
        end
    
        source_build_phase = target.source_build_phase
        build_phases = target.build_phases
    
        titles_of_phases_to_remove.each do |t|
          existing_build_phase = build_phases.find { |b| b.respond_to?(:name) and b.name == t} 
          build_phases.delete(existing_build_phase) unless existing_build_phase.nil?
        end
      end
    end
    rollout_group.remove_from_project unless rollout_group.nil?
  end
end
