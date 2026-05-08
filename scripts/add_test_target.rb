#!/usr/bin/env ruby
# Adds the `plankAITests` unit-test bundle target to plankAI.xcodeproj and
# wires it into the shared scheme so `⌘U` runs the tests. Idempotent —
# safe to re-run if the target or testable reference is missing.
#
# Usage: ruby Scripts/add_test_target.rb
#
# Requires the `xcodeproj` gem (ships with CocoaPods; standalone install:
# `gem install xcodeproj`).

require 'xcodeproj'

PROJECT_PATH    = File.expand_path('../plankAI.xcodeproj', __dir__)
TESTS_DIR_NAME  = 'plankAITests'
APP_TARGET_NAME = 'plankAI'
TEST_TARGET     = 'plankAITests'
DEPLOY_TARGET   = '17.6'
BUNDLE_ID       = 'com.bk.plankAITests'

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
abort "Couldn't find app target '#{APP_TARGET_NAME}'" unless app_target

# 1. Create the test target (idempotent).
test_target = project.targets.find { |t| t.name == TEST_TARGET }
if test_target
  puts "[add_test_target] target '#{TEST_TARGET}' already exists — reusing"
else
  test_target = project.new_target(
    :unit_test_bundle,
    TEST_TARGET,
    :ios,
    DEPLOY_TARGET,
    nil,
    :swift
  )
  puts "[add_test_target] created target '#{TEST_TARGET}'"
end

# 2. Build settings — wire host app + bundle id + deployment target.
test_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_NAME']              = TEST_TARGET
  bs['BUNDLE_LOADER']             = '$(TEST_HOST)'
  bs['TEST_HOST']                 = "$(BUILT_PRODUCTS_DIR)/#{APP_TARGET_NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/#{APP_TARGET_NAME}"
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  bs['SWIFT_VERSION']             = '5.0'
  bs['GENERATE_INFOPLIST_FILE']   = 'YES'
  bs['CLANG_ENABLE_MODULES']      = 'YES'
  bs['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
end

# 3. Dependency on the app target.
unless test_target.dependencies.any? { |d| d.target == app_target }
  test_target.add_dependency(app_target)
  puts "[add_test_target] added host-app dependency on '#{APP_TARGET_NAME}'"
end

# 4. Add the test source files.
test_group = project.main_group[TESTS_DIR_NAME] ||
             project.main_group.new_group(TESTS_DIR_NAME, TESTS_DIR_NAME)

test_files = %w[WeightTests.swift StreakCalculatorTests.swift WorkoutGeneratorTests.swift]
test_files.each do |filename|
  existing_ref = test_group.files.find { |f| f.path == filename }
  file_ref = existing_ref || test_group.new_reference(filename)

  already_in_phase = test_target.source_build_phase.files_references.include?(file_ref)
  unless already_in_phase
    test_target.add_file_references([file_ref])
    puts "[add_test_target] added '#{filename}' to source build phase"
  end
end

project.save
puts "[add_test_target] project saved"

# 5. Wire the test target into the shared scheme.
scheme_path = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes', "#{APP_TARGET_NAME}.xcscheme")
abort "Couldn't find shared scheme at #{scheme_path}" unless File.exist?(scheme_path)

scheme = Xcodeproj::XCScheme.new(scheme_path)
already_testable = scheme.test_action.testables.any? do |t|
  t.buildable_references.any? { |br| br.target_name == TEST_TARGET }
end

if already_testable
  puts "[add_test_target] scheme already references test target — skipping"
else
  testable_ref = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  scheme.test_action.add_testable(testable_ref)
  scheme.save_as(PROJECT_PATH, APP_TARGET_NAME, true)
  puts "[add_test_target] scheme updated with test target"
end

puts "[add_test_target] done"
