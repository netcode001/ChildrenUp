import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

class SpeechRecognitionService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    break
                case .denied:
                    self.errorMessage = "用户拒绝了语音识别权限"
                case .restricted:
                    self.errorMessage = "语音识别在此设备上受限"
                case .notDetermined:
                    self.errorMessage = "语音识别权限未确定"
                @unknown default:
                    self.errorMessage = "未知错误"
                }
            }
        }
    }
    
    func startRecording(to url: URL? = nil) {
        // Cancel existing task if any
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "无法设置音频会话: \(error.localizedDescription)"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Enable on-device recognition for faster speed and offline support (iOS 13+)
        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition ?? false {
                recognitionRequest?.requiresOnDeviceRecognition = true
            }
        }
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            self.errorMessage = "无法创建识别请求"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup Audio File
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        if let url = url {
            do {
                audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
            } catch {
                print("Error creating audio file: \(error)")
            }
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
                self.audioFile = nil
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            self.isRecording = true
            self.errorMessage = nil
            self.transcript = ""
        } catch {
            self.errorMessage = "无法启动音频引擎: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
}
