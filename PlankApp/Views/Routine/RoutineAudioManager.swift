import AVFoundation

/// Plays voice clips during routine sessions.
/// Manages AVAudioSession for background audio — voice coaching continues when phone is locked.
@Observable
@MainActor
final class RoutineAudioManager {
    private var player: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?
    private var lastPlayTime: Date = .distantPast

    /// Minimum seconds between clips. Prevents overlaps.
    private let cooldown: TimeInterval = 3.0

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    // MARK: - Audio Session

    /// Activate audio session at session start. Enables background audio.
    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback: audio continues in background
            // .duckOthers: lower other app audio (music) during clips
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Fallback: at least try basic playback
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
        // Start silent loop to keep audio session alive during hold gaps
        startSilenceLoop()
    }

    /// Deactivate audio session at session end. Let other apps resume.
    func deactivate() {
        stopSilenceLoop()
        player?.stop()
        player = nil
        // Notify other apps they can resume (e.g. music)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Silent Loop (keeps background audio alive)

    /// iOS kills background audio if nothing plays for ~30s.
    /// A silent audio loop prevents this during exercise holds.
    private func startSilenceLoop() {
        guard silencePlayer == nil else { return }
        // Generate 1 second of silence as PCM data
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)

        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        let dataSize = numSamples * 4
        let data = Data(count: dataSize) // all zeros = silence

        // Write a minimal WAV in memory
        var wavData = Data()
        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        var fileSize = UInt32(36 + dataSize).littleEndian
        wavData.append(Data(bytes: &fileSize, count: 4))
        wavData.append(contentsOf: "WAVE".utf8)
        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        var fmtSize = UInt32(16).littleEndian
        wavData.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat = UInt16(3).littleEndian // IEEE float
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var channels = UInt16(1).littleEndian
        wavData.append(Data(bytes: &channels, count: 2))
        var rate = UInt32(44100).littleEndian
        wavData.append(Data(bytes: &rate, count: 4))
        var byteRate = UInt32(44100 * 4).littleEndian
        wavData.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = UInt16(4).littleEndian
        wavData.append(Data(bytes: &blockAlign, count: 2))
        var bitsPerSample = UInt16(32).littleEndian
        wavData.append(Data(bytes: &bitsPerSample, count: 2))
        // data chunk
        wavData.append(contentsOf: "data".utf8)
        var chunkSize = UInt32(dataSize).littleEndian
        wavData.append(Data(bytes: &chunkSize, count: 4))
        wavData.append(data)

        silencePlayer = try? AVAudioPlayer(data: wavData)
        silencePlayer?.numberOfLoops = -1 // loop forever
        silencePlayer?.volume = 0.01      // near-silent
        silencePlayer?.play()
    }

    private func stopSilenceLoop() {
        silencePlayer?.stop()
        silencePlayer = nil
    }

    // MARK: - Playback

    func play(_ clipName: String, force: Bool = false) {
        if !force && isPlaying { return }
        if !force && Date().timeIntervalSince(lastPlayTime) < cooldown { return }

        guard let url = Bundle.main.url(forResource: clipName, withExtension: "m4a") else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        lastPlayTime = Date()
    }

    func playRandom(_ clipNames: [String], force: Bool = false) {
        guard let clip = clipNames.randomElement() else { return }
        play(clip, force: force)
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Routine Events

    func onSessionDone() {
        playRandom(["routine_done_1", "routine_done_2", "routine_done_3"], force: true)
    }

    func onExercisePreview(exerciseId: String) {
        play("intro_\(exerciseId)", force: true)
    }

    func onExerciseStart() {
        play("exercise_countdown", force: true)
    }

    func onExerciseAlmost() {
        play("exercise_almost")
    }

    func onExerciseDone() {
        play("exercise_done")
    }

    func onRest() {
        playRandom(["rest_1", "rest_2", "rest_3", "rest_4"], force: true)
    }

    func onSkip() {
        playRandom(["skip_1", "skip_2"], force: true)
    }

    /// Periodic encouragement during active phase. Wider spacing, respects cooldown.
    func onActiveTick(exerciseType: ExerciseType, secondsIn: Int, duration: Int) {
        let remaining = duration - secondsIn

        // 5 seconds left
        if remaining == 5 {
            onExerciseAlmost()
            return
        }

        // Periodic cues every ~12 seconds, starting at 10s in, stop 8s before end
        guard secondsIn >= 10, secondsIn % 12 == 0, remaining > 8 else { return }

        if exerciseType == .static {
            playRandom(["hold_1", "hold_2", "hold_3", "hold_4", "hold_5", "hold_6"])
        } else {
            playRandom([
                "tempo_1", "tempo_2", "tempo_3", "tempo_4",
                "tempo_twist_1", "tempo_twist_2",
                "tempo_drive_1", "tempo_drive_2",
            ])
        }
    }
}
