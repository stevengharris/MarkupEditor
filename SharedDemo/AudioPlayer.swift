//
//  AudioPlayer.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/22.
//

import AVFoundation

class AudioPlayer {
    static var shared = AudioPlayer()
    var avPlayer: AVAudioPlayer?
    
    /// Return the bundle that is appropriate for the packaging.
    func bundle() -> Bundle {
        // If you use the framework as a dependency, the bundle can be identified from
        // the place where MarkupWKWebView is found. If you use the Swift package as a
        // dependency, it does some BundleFinder hocus pocus behind the scenes to allow
        // Bundle to respond to module.
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: AudioPlayer.self)
        #endif
    }
    
    func playSound(filename: String) {
        let path = bundle().path(forResource: filename, ofType: nil)!
        let url = URL(fileURLWithPath: path)
        do {
            avPlayer = try AVAudioPlayer(contentsOf: url)
            avPlayer?.play()
        } catch {
            print("Could not load audio file \(filename)")
        }
    }
    
}
