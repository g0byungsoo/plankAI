#!/usr/bin/env ruby
# Remove Swift files from the plankAI target + disk. Inverse of
# add_swift_file.rb. Usage: ruby scripts/remove_swift_file.rb <path>...
require 'xcodeproj'
PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
REPO_ROOT    = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'plankAI' }
ARGV.each do |rel|
  abs = File.join(REPO_ROOT, rel)
  refs = project.files.select { |f| f.real_path.to_s == abs }
  refs.each do |ref|
    target.source_build_phase.remove_file_reference(ref)
    ref.remove_from_project
  end
  puts "removed ref(s): #{rel} (#{refs.count})"
end
project.save
