#!/usr/bin/env ruby
# Adds every voice-clip .m4a in PlankApp/Resources/VoiceClips/ to the
# plankAI app target's Resources build phase if it isn't already there.
# Idempotent — re-running is a no-op once everything is in sync.
#
# Why this exists: the ElevenLabs generation script writes clips to the
# resource directory, but the Xcode project file is the source of
# truth for what actually ships in the bundle. Adding ~500 files via
# the Xcode UI is impractical; this script keeps the two in sync.
#
# Usage: ruby scripts/sync_voice_clips_to_pbxproj.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../plankAI.xcodeproj', __dir__)
CLIPS_DIR    = File.expand_path('../PlankApp/Resources/VoiceClips', __dir__)
APP_TARGET   = 'plankAI'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == APP_TARGET }
abort "Couldn't find target '#{APP_TARGET}'" unless target

# Resources build phase already-bundled basenames
phase = target.resources_build_phase
bundled = phase.files
                 .map { |bf| bf.file_ref&.path || bf.file_ref&.name }
                 .compact
                 .map { |p| File.basename(p) }
                 .to_set

# Find or create the VoiceClips group inside the project
voice_group = nil
project.main_group.recursive_children_groups.each do |g|
  if g.name == 'VoiceClips' || g.path == 'VoiceClips' ||
     g.real_path.to_s.end_with?('PlankApp/Resources/VoiceClips')
    voice_group = g
    break
  end
end
abort "Couldn't locate the VoiceClips group in the project tree" unless voice_group

added = 0
skipped = 0

Dir.glob(File.join(CLIPS_DIR, '*.m4a')).sort.each do |path|
  basename = File.basename(path)
  if bundled.include?(basename)
    skipped += 1
    next
  end

  file_ref = voice_group.new_reference(basename)
  file_ref.last_known_file_type = 'file'
  phase.add_file_reference(file_ref)
  added += 1
end

project.save
puts "[sync] added #{added} clips, skipped #{skipped} already-bundled"
