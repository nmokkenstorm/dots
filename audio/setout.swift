import CoreAudio

let want = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslateUIDToDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var uid = want as CFString
var id = AudioObjectID(0)
var size = UInt32(MemoryLayout<AudioObjectID>.size)
_ = withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, UInt32(MemoryLayout<CFString>.size), $0, &size, &id) }
var d = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
print(id == 0 ? "no device \(want)" : (AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &d, 0, nil, size, &id) == noErr ? "default out -> \(want)" : "set failed"))
