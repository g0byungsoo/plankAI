#!/usr/bin/env ruby
# Add resource files (audio, images, etc.) to the plankAI Xcode project's
# Copy Bundle Resources build phase. Idempotent — safe to re-run.
#
# Mirror of add_swift_file.rb (which adds to Sources build phase); this
# variant adds to the Resources build phase instead, which is what
# bundles non-compiled assets like .m4a / .mp3 / .json into the .app.
#
# Usage: ruby Scripts/add_resource_file.rb <relative-path> [<relative-path>…]
# Paths are relative to the repo root.

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
REPO_ROOT    = File.expand_path('..', __dir__)
APP_TARGET   = 'plankAI'

abort "Usage: ruby Scripts/add_resource_file.rb <relative-path>..." if ARGV.empty?

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == APP_TARGET }
abort "Couldn't find target '#{APP_TARGET}'" unless target

resources_phase = target.resources_build_phase
bundled_paths = resources_phase.files.map { |bf| bf.file_ref&.real_path&.to_s }.compact.to_set

added = 0
skipped = 0

ARGV.each do |rel_path|
  abs_path = File.join(REPO_ROOT, rel_path)
  unless File.exist?(abs_path)
    warn "skip (missing on disk): #{rel_path}"
    next
  end

  if bundled_paths.include?(abs_path)
    skipped += 1
    next
  end

  components = Pathname(rel_path).each_filename.to_a
  filename = components.pop
  group = project.main_group
  components.each do |segment|
    existing = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path == segment || c.name == segment) }
    group = existing || group.new_group(segment, segment)
  end

  file_ref = group.files.find { |f| f.path == filename } || group.new_reference(filename)
  resources_phase.add_file_reference(file_ref) unless resources_phase.files_references.include?(file_ref)
  added += 1
  puts "added: #{rel_path}"
end

project.save
puts "done — added #{added}, skipped #{skipped} already-bundled"
