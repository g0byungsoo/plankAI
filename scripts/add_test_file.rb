#!/usr/bin/env ruby
# Add Swift source files to the plankAITests target. Mirror of
# add_swift_file.rb but targets the unit-test bundle instead of the app.
# Idempotent — safe to re-run.
#
# Usage: ruby scripts/add_test_file.rb <relative-path> [<relative-path>...]
# Paths are relative to the repo root (e.g. plankAITests/MyTests.swift).

require 'xcodeproj'
require 'pathname'
require 'set'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
REPO_ROOT    = File.expand_path('..', __dir__)
TEST_TARGET  = 'plankAITests'
TESTS_GROUP  = 'plankAITests'

abort "Usage: ruby scripts/add_test_file.rb <relative-path>..." if ARGV.empty?

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TEST_TARGET }
abort "Couldn't find target '#{TEST_TARGET}'" unless target

sources_phase = target.source_build_phase
bundled_paths = sources_phase.files.map { |bf| bf.file_ref&.real_path&.to_s }.compact.to_set

test_group = project.main_group[TESTS_GROUP] ||
             project.main_group.new_group(TESTS_GROUP, TESTS_GROUP)

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

  filename = File.basename(rel_path)
  file_ref = test_group.files.find { |f| f.path == filename } || test_group.new_reference(filename)
  sources_phase.add_file_reference(file_ref) unless sources_phase.files_references.include?(file_ref)
  added += 1
  puts "added: #{rel_path}"
end

project.save
puts "done — added #{added}, skipped #{skipped} already-bundled"
