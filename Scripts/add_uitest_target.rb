#!/usr/bin/env ruby
# Adds the `plankAIUITests` UI-test bundle target. Mirrors
# add_test_target.rb. Idempotent.
#
# Usage: ruby Scripts/add_uitest_target.rb

require 'xcodeproj'

PROJECT_PATH    = File.expand_path('../plankAI.xcodeproj', __dir__)
TESTS_DIR_NAME  = 'plankAIUITests'
APP_TARGET_NAME = 'plankAI'
TEST_TARGET     = 'plankAIUITests'
DEPLOY_TARGET   = '17.6'
BUNDLE_ID       = 'com.bk.plankAIUITests'

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
abort "Couldn't find app target '#{APP_TARGET_NAME}'" unless app_target

test_target = project.targets.find { |t| t.name == TEST_TARGET }
if test_target
  puts "[add_uitest_target] target '#{TEST_TARGET}' already exists — reusing"
else
  test_target = project.new_target(
    :ui_test_bundle,
    TEST_TARGET,
    :ios,
    DEPLOY_TARGET,
    nil,
    :swift
  )
  puts "[add_uitest_target] created target '#{TEST_TARGET}'"
end

test_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_NAME']               = TEST_TARGET
  bs['PRODUCT_BUNDLE_IDENTIFIER']  = BUNDLE_ID
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  bs['SWIFT_VERSION']              = '5.0'
  bs['GENERATE_INFOPLIST_FILE']    = 'YES'
  bs['TEST_TARGET_NAME']           = APP_TARGET_NAME
end

unless test_target.dependencies.any? { |d| d.target == app_target }
  test_target.add_dependency(app_target)
  puts "[add_uitest_target] added dependency on '#{APP_TARGET_NAME}'"
end

# Source files from plankAIUITests/
group = project.main_group.find_subpath(TESTS_DIR_NAME, true)
group.set_source_tree('<group>')
group.set_path(TESTS_DIR_NAME)

dir = File.expand_path("../#{TESTS_DIR_NAME}", __dir__)
existing = test_target.source_build_phase.files.map { |bf| bf.file_ref&.path }.compact
Dir.glob("#{dir}/*.swift").each do |f|
  basename = File.basename(f)
  next if existing.include?(basename)
  ref = group.files.find { |fr| fr.path == basename } || group.new_reference(basename)
  test_target.add_file_references([ref])
  puts "[add_uitest_target] added #{basename}"
end

project.save
puts "[add_uitest_target] saved"
