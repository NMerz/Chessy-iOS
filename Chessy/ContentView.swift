//
//  ContentView.swift
//  Chessy
//
//  Created by Nathan Merz on 9/14/24.
//

import SwiftUI
import AVKit
import PhotosUI
import SwiftData

protocol PreviewSource: Sendable {
    func connect(to target: PreviewTarget)
}

protocol PreviewTarget {
    func setSession(_ session: AVCaptureSession)
}

struct VideoPreview: UIViewRepresentable {
    let previewSource: PreviewSource
    
    func makeUIView(context: Context) -> UIView {
        let newView = VideoView()
        previewSource.connect(to: newView)
        return newView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

class VideoView: UIView, PreviewTarget {
    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
       layer as! AVCaptureVideoPreviewLayer
    }
}

struct MoveParts: Codable, Equatable, Hashable {
    let piece: String?
    let source: String?
    let capture: Bool?
    let rank: String?
    let file: String?
    let check: Bool?
    let ks_castle: Bool
    let qs_castle: Bool
}

struct Vertex: Codable, Equatable, Hashable {
    let x: Int
    let y: Int
}

@Model
class MovePredictionsStorage {
    var gameName: String
    var predictionsJsonString: String
    
    init(gameName: String = "Current", predictionsJsonString: String = "{}") {
        self.gameName = gameName
        self.predictionsJsonString = predictionsJsonString
    }
}

struct MovePredictions: Codable, Equatable, Hashable {
    
//    init(past_moves: [String]? = nil, google: [[MoveParts?]] = [], openai: [[MoveParts?]] = [], amazon: [[MoveParts?]] = [], cell_bounds: [[Vertex]] = []) {
//        self.past_moves = past_moves
//        self.google = google
//        self.openai = openai
//        self.amazon = amazon
//        self.cell_bounds = cell_bounds
//    }
    
    var past_moves: [String]?
    let google: [[MoveParts?]]
    let openai: [[MoveParts?]]
    let amazon: [[MoveParts?]]
    let cell_bounds: [[Vertex]]
}

struct ContentView: View {
    let cameraActor = CameraActor.shared
    @State var processing = false
    @State var navPath = NavigationPath()
    @State var selectedImageContents: String = ""
    @State var imageUrl: URL? = nil
    @State var imageCoverup = 0.0
    
    var body: some View {
        NavigationStack (path: $navPath) {
            VStack {
                if processing {
                    Image(uiImage: UIImage(contentsOfFile: (imageUrl?.path())!)!).resizable().frame(width: 200, height: 200 * 16 / 9, alignment: .center).overlay {
                        Color.gray.opacity(0.5).frame(width: 200, height: imageCoverup).offset( y: (200 * 16 / 9 - imageCoverup)/2)
                    }
                    Text("The AI is processing the image.")
                    ProgressView()
                } else {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Hello, world!")
                    VideoPreview(previewSource: cameraActor.previewSource).ignoresSafeArea(.all)
                    Button("capture") {
                        Task {
                            let photoData = try await cameraActor.capturePhoto()
                            imageUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: UUID().uuidString).appendingPathExtension(for: .jpeg)
                            try UIImage(ciImage: CIImage(image: UIImage(data: photoData)!)!.oriented(.right)).jpegData(compressionQuality: 1.0)!.write(to: imageUrl!)
                            imageCoverup = 200 * 16 / 9
                            processing = true
                            withAnimation(.linear(duration: 30)) {
                                imageCoverup = imageCoverup * 0.1
                            }
                            do {
                                let predictions = try await Poster.postFor(MovePredictions.self, request: URLRequest(url: URL (string: "https://ocr-chess-game-965053369291.us-central1.run.app")!), postString: photoData.base64EncodedString())
                                print(predictions)
                                withAnimation {
                                    imageCoverup = 0
                                }
                                try await Task.sleep(for: .seconds(1))
                                navPath.append(EditView(movePredictions: predictions, navPath: $navPath, imageUrl: imageUrl!))
                                print(navPath.count)
                                processing = false
                            } catch let err {
                                print(err)
                            }
                        }
                    }.onAppear(perform: {
                        Task {
                            try await cameraActor.setUpCaptureSession()
                        }
                    })
                    AddVideoView(imageContents: $selectedImageContents, imageUrl: $imageUrl).onChange(of: selectedImageContents) { oldValue, newValue in
                        Task {
                            imageCoverup = 200 * 16 / 9
                            processing = true
                            withAnimation (.linear(duration: 30)) {
                                imageCoverup = imageCoverup * 0.1
                            }
                            do {
                                let predictions = try await Poster.postFor(MovePredictions.self, request: URLRequest(url: URL (string: "https://ocr-chess-game-965053369291.us-central1.run.app")!), postString: newValue)
//                                let predictions = MovePredictions(google: [[MoveParts(piece: nil, source: nil, capture: false, rank: "e", file: "4", check: false, ks_castle: false, qs_castle: false), MoveParts(piece: nil, source: nil, capture: false, rank: "e", file: "5", check: false, ks_castle: false, qs_castle: false)]], openai: [[nil, nil]], amazon: [[]], cell_bounds: [[Vertex(x: 57, y: 166), Vertex(x: 121, y: 198)], [Vertex(x: 121, y: 166), Vertex(x: 265, y: 198)]])
//                                try await Task.sleep(for: .seconds(5))
                                
                                
                                withAnimation {
                                    imageCoverup = 0
                                }
                                try await Task.sleep(for: .seconds(1))
                                print(predictions)
                                print("imageUrl", imageUrl?.path())
                                print(UIImage(contentsOfFile: imageUrl!.path()))
                                print(CIImage(contentsOf: imageUrl!)!.extent)
                                navPath.append(EditView(movePredictions: predictions, navPath: $navPath, imageUrl: imageUrl!))
                                print(navPath.count)
                                processing = false
                            } catch let err {
                                print(err)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: PgnView.self) { newView in
                newView
            }.navigationDestination(for: EditView.self) { newView in
                newView
            }
            .padding()
        }
//        .onAppear {
//            //Testing bypass
//            navPath.append(EditView(movePredictions: MovePredictions(google: [[MoveParts(piece: nil, source: nil, capture: false, rank: "e", file: "4", check: false, ks_castle: false, qs_castle: false), MoveParts(piece: nil, source: nil, capture: false, rank: "e", file: "5", check: false, ks_castle: false, qs_castle: false)]], openai: [[nil, nil]], amazon: [[]]), navPath: $navPath))
//        }
    }
}

struct AddVideoView: View {
    @State var imageContents: Binding<String>
    @State var imageUrl: Binding<URL?>
    @State var localVideoModel: VideoModel
    
    init(imageContents: Binding<String>, imageUrl: Binding<URL?>) {
        self.imageContents = imageContents
        self.imageUrl = imageUrl
        self.localVideoModel = VideoModel(imageContents: imageContents, imageUrl: imageUrl)
    }
    
    
    var body: some View {
        PhotosPicker(selection: Binding(get: {
            return localVideoModel.newRecipeVideo
        }, set: { newPick in
            localVideoModel.newRecipeVideo = newPick
        }), matching: .images, photoLibrary: .shared()) {
            RoundedRectangle(cornerRadius: 10.0).overlay {
                Text("Upload").bold().foregroundStyle(Color.white)
            }
        }.frame(width: 100, height: 33)
    }
}



class VideoModel {
    init(imageContents: Binding<String>, imageUrl: Binding<URL?>) {
        self.imageContents = imageContents
        self.imageUrl = imageUrl
        newRecipeVideo = nil
    }
    
    var imageContents: Binding<String>
    var imageUrl: Binding<URL?>
    
    var newRecipeVideo: Optional<PhotosPickerItem> {
        didSet {
            if newRecipeVideo == nil {
                return
            }
            Task {
                let newImageContent = try await newRecipeVideo!.loadTransferable(type: UploadableVideo.self)
                if newImageContent == nil {
                    return
                }
                await MainActor.run {
                    imageContents.wrappedValue = newImageContent!.imageContents
                    imageUrl.wrappedValue = newImageContent!.imageUrl
                }
            }
        }
    }
    
    class VideoSaveError: Error {
        
    }
    
    struct UploadableVideo: Transferable {
        let imageContents: String
        let imageUrl: URL
        
        static var transferRepresentation: some TransferRepresentation {
            
            FileRepresentation(importedContentType: .image) { movieFile in
                print(movieFile)
                let baseDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let pathAvailableOutsideClosure = baseDir.appendingPathComponent("currentImage." + movieFile.file.pathExtension)
                print(pathAvailableOutsideClosure)
                do {
                    try? FileManager.default.removeItem(at: pathAvailableOutsideClosure)
                    print(pathAvailableOutsideClosure)
                    try FileManager.default.copyItem(at: movieFile.file, to: pathAvailableOutsideClosure)
                } catch {
                    print("unable to copy", error)
                    throw VideoSaveError()
                }
                let contents = try Data(contentsOf: pathAvailableOutsideClosure).base64EncodedString()
                if contents == nil {
                    print("unable to load contents")
                    throw VideoSaveError()
                } else {
                    return self.init(imageContents: contents, imageUrl: pathAvailableOutsideClosure)
                }

                
                
                
            }
        }
    }
}


#Preview {
    ContentView()
}
