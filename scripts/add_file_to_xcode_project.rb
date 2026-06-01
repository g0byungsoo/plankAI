#!/usr/bin/env ruby
# Add a Swift file to plankAI.xcodeproj's plankAI target.
# Usage: ruby add_file_to_xcode_project.rb PATH/TO/File.swift [GROUP/PATH]
#
# Defaults: group path inferred from the file's relative location under
# PlankApp/. For files outside PlankApp/, pass the group path explicitly
# (e.g. "Views/Onboarding").

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
TARGET_NAME = 'plankAI'

file_arg = ARGV[0]
group_arg = ARGV[1]

abort("usage: add_file_to_xcode_project.rb <file.swift> [group/path]") if file_arg.nil?

abs_path = File.expand_path(file_arg)
abort("file not found: #{abs_path}") unless File.exist?(abs_path)

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort("target '#{TARGET_NAME}' not found")

# Already in project? skip.
existing = project.files.find { |f| f.real_path.to_s == abs_path }
if existing
  puts "already in project: #{abs_path}"
  exit 0
end

# Infer group from file location under PlankApp/
group_path = group_arg
if group_path.nil?
  repo_root = File.expand_path('..', __dir__)
  rel = abs_path.sub("#{repo_root}/", '')
  parts = rel.split('/')
  abort("can't infer group; pass GROUP/PATH arg") unless parts.first == 'PlankApp'
  group_path = parts[1..-2].join('/')
end

# Walk/create group structure under the project's main group.
plankapp_group = project.main_group.find_subpath('PlankApp', false) or abort("group 'PlankApp' not found in project")
group = plankapp_group.find_subpath(group_path, true)
group.set_source_tree('<group>')

# Add file reference + build file.
file_ref = group.new_file(abs_path)
target.add_file_references([file_ref])

project.save
puts "added: #{abs_path}"
puts "  group: PlankApp/#{group_path}"
puts "  target: #{TARGET_NAME}"
