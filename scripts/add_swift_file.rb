#!/usr/bin/env ruby
# Add Swift source files to the plankAI Xcode project. Idempotent —
# safe to re-run; existing references are reused, not duplicated.
#
# Why this exists: the project uses legacy PBX groups (not folder-sync),
# so dropping a .swift file on disk doesn't make it compile. This
# script handles group creation along the path and adds the file to
# the app target's Sources build phase.
#
# Usage: ruby Scripts/add_swift_file.rb <relative-path> [<relative-path>…]
# Paths are relative to the repo root (e.g. PlankApp/Analytics/AnalyticsManager.swift).

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
REPO_ROOT    = File.expand_path('..', __dir__)
APP_TARGET   = 'plankAI'

abort "Usage: ruby Scripts/add_swift_file.rb <relative-path>..." if ARGV.empty?

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == APP_TARGET }
abort "Couldn't find target '#{APP_TARGET}'" unless target

sources_phase = target.source_build_phase
bundled_paths = sources_phase.files.map { |bf| bf.file_ref&.real_path&.to_s }.compact.to_set

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

  # Walk the path and find-or-create groups. For PlankApp/Analytics/AnalyticsManager.swift
  # this yields the PlankApp group → Analytics subgroup, then attaches the file ref.
  components = Pathname(rel_path).each_filename.to_a
  filename = components.pop
  group = project.main_group
  components.each do |segment|
    existing = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path == segment || c.name == segment) }
    group = existing || group.new_group(segment, segment)
  end

  # Avoid duplicating a file ref that already lives in the group from
  # a prior partial state.
  file_ref = group.files.find { |f| f.path == filename } || group.new_reference(filename)
  sources_phase.add_file_reference(file_ref) unless sources_phase.files_references.include?(file_ref)
  added += 1
  puts "added: #{rel_path}"
end

project.save
puts "done — added #{added}, skipped #{skipped} already-bundled"
