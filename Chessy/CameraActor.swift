//
//  CameraActor.swift
//  Chessy
//
//  Created by Nathan Merz on 9/14/24.
//

import Foundation
import AVFoundation

struct DefaultPreviewSource: PreviewSource {
    
    let session: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    func connect(to target: PreviewTarget) {
        target.setSession(session)
    }
}

actor CameraActor {
    var setup: Bool = false
    var movieUrl: Optional<URL> = nil
    var captureSession = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?

    
    static var shared = CameraActor()
    
    init() {
        previewSource = DefaultPreviewSource(session: captureSession)
    }
    static var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            // Determine if the user previously authorized camera access.
            var isAuthorized = status == .authorized
            
            // If the system hasn't determined the user's authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
    
    nonisolated let previewSource: PreviewSource

    func setUpCaptureSession() async throws {
        guard await CameraActor.isAuthorized else { throw CameraError("not authorized to use camera+mic") }
        if setup {
            return
        }
        
        if AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) == nil {
            throw CameraError("no camera")
        }
        captureSession.sessionPreset = .photo
        let defaultCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        guard
            let visualInput = try? AVCaptureDeviceInput(device: defaultCamera),
            captureSession.canAddInput(visualInput)
            else { throw CameraError("bad input setting") }
        captureSession.addInput(visualInput)
        let photoOutput = AVCapturePhotoOutput()
        
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError("Unable to add photo output to capture session.")
        }
        captureSession.addOutput(photoOutput)
        self.photoOutput = photoOutput
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        setup = true
        
    }

    
    private var recordingUrl: Optional<URL> = nil
    
    func capturePhoto() async throws -> Data {
        var photoSettings = AVCapturePhotoSettings()

        if photoOutput == nil {
            throw CameraError("Missing photo output configuration when capturing photo")
        }
        if photoOutput!.availablePhotoCodecTypes.contains(.jpeg) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        }
        let delegate = PhotoCaptureDelegate()
        let capturedPhoto = try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            print("1")
            print("2")
            photoOutput!.capturePhoto(with: photoSettings, delegate: delegate)
            print("3")
        }
        print("cp", capturedPhoto.fileDataRepresentation()!.base64EncodedString().prefix(10))
        if capturedPhoto.fileDataRepresentation() == nil {
            throw CameraError("unable to represent photo as file")
        }
        return capturedPhoto.fileDataRepresentation()!
    }
    
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var continuation: CheckedContinuation<AVCapturePhoto, Error>? = nil

    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        print("4")
        print("p", photo)
        continuation?.resume(returning: photo)
    }
}

class CameraError: Error {
    init (_ errorString: String) {
        print(errorString)
    }
}
