#!/usr/bin/env ruby
# One-shot: link the PostHog package product to the plankAI app target.
# The user added the SPM package via Xcode UI (which created the package
# reference) but didn't tick the plankAI target during "Add Package".
# Idempotent — skips if PostHog is already linked.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
APP_TARGET   = 'plankAI'
PRODUCT_NAME = 'PostHog'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == APP_TARGET }
abort "Couldn't find target '#{APP_TARGET}'" unless target

# Already linked?
existing = target.package_product_dependencies.find { |d| d.product_name == PRODUCT_NAME }
if existing
  puts "skip — #{PRODUCT_NAME} already linked to #{APP_TARGET}"
  exit 0
end

# Find the XCRemoteSwiftPackageReference for posthog-ios
posthog_pkg = project.root_object.package_references.find do |ref|
  ref.respond_to?(:repositoryURL) && ref.repositoryURL.to_s.include?('posthog-ios')
end
abort "Couldn't find posthog-ios package reference in the project" unless posthog_pkg

# Create the product dependency and attach it.
dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dep.package = posthog_pkg
dep.product_name = PRODUCT_NAME

target.package_product_dependencies << dep

# Add it to the Frameworks build phase so the linker picks it up.
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = dep
target.frameworks_build_phase.files << build_file

project.save
puts "linked: #{PRODUCT_NAME} → #{APP_TARGET}"
