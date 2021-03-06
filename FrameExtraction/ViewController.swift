//
//  ViewController.swift
//  Created by Bobo on 29/12/2016.
//

import UIKit
import AVFoundation
import Vision
import CoreML
import ImageIO

let kRecognitionTimePeriod: Double = 30

class ViewController: UIViewController, FrameExtractorDelegate {
    
    var frameExtractor: FrameExtractor!
    
    var userList: [String:Int] = ["donghang": 1, "huyen": 3, "hoc": 5, "nam": 6]
    var classifiedList: [String:Date] = [:]
    var isFaceExtracting: Bool = false
    var isFaceRecognize: Bool = false
    var totalFacesCount = 0
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var firstPersonLabel: UILabel!
    @IBOutlet weak var secondPersonLabel: UILabel!
    @IBOutlet weak var thirdPersonLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        firstPersonLabel.text = nil
        secondPersonLabel.text = nil
        thirdPersonLabel.text = nil
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
    }
    
    func captured(image: UIImage) {
        imageView.image = image
        
        // send image capture by phone to analyze it
        faceExtraction(image: image)
    }
    
    // MARK: Face detection
    func faceExtraction(image: UIImage) {
        let request = VNDetectFaceRectanglesRequest { (req, err) in
            self.isFaceExtracting = false
            if let err = err {
                print("Failed to detect faces:", err)
                return
            }
            
            self.removeDetectView()
            self.totalFacesCount = (req.results?.count)!
            req.results?.forEach({ (res) in
                DispatchQueue.main.async {
                    guard let faceObservation = res as? VNFaceObservation else { return }
                    let boundingBox = faceObservation.boundingBox
                    let size = CGSize(width: boundingBox.width * self.view.bounds.width,
                                      height: boundingBox.height * self.view.bounds.height * 2)
                    let origin = CGPoint(x: boundingBox.minX * self.view.bounds.width - boundingBox.width * self.view.bounds.width * 0.3,
                                         y: (1 - faceObservation.boundingBox.minY) * self.view.bounds.height - size.height)
                    
                    self.applyDetectView(frame: CGRect(origin: origin, size: size))
                    
                    // crop only human's face in captured image
                    let faceCGImage = image.cgImage?.cropping(to: CGRect(origin: origin, size: size))
                    if let faceRaw = faceCGImage {
                        // use CoreML to recognize face in mlmodel file
                        self.updateClassifications(for: UIImage(cgImage: faceRaw))
                    }
                }
            })
        }
        
        guard let cgImage = image.cgImage else { return }
        
        if !isFaceExtracting {
            DispatchQueue.global(qos: .background).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    self.isFaceExtracting = true
                    try handler.perform([request])
                } catch let reqErr {
                    print("Failed to perform request:", reqErr)
                }
            }
        }
    }
    
    func removeDetectView() {
        let viewTagInitial = 99
        for i in viewTagInitial ..< 99 + totalFacesCount {
            DispatchQueue.main.async {
                if let _ = self.view.viewWithTag(i) {
                    self.view.viewWithTag(i)?.removeFromSuperview()
                }
            }
        }
    }
    
    func applyDetectView(frame: CGRect) {
        let viewTagInitial = 99
        let detectView = UIView()
        detectView.frame = frame
        detectView.layer.borderColor = UIColor.red.cgColor
        detectView.layer.borderWidth = 3
        
        for i in viewTagInitial ..< 99 + totalFacesCount {
            if let _ = view.viewWithTag(i) {
                continue
            } else {
                detectView.tag = i
                self.view.addSubview(detectView)
            }
        }
    }
    
    // MARK: - Image Classification
    
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: PlayingTime().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        //        classificationLabel.text = "Classifying..."
        print("Classifying...")

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {    
        DispatchQueue.main.async {
            guard let results = request.results else {
                //                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                print("Unable to classify image.\n\(error!.localizedDescription)")
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                print("Nothing recognized.")
                //                self.classificationLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(2)
                
                for i in 1 ..< topClassifications.count {
                    self.checkPersonIsTrusted(confidence: topClassifications[topClassifications.startIndex + i].confidence, name: topClassifications[topClassifications.startIndex + i].identifier)
                }
                
//                let descriptions = topClassifications.map { classification in
//                    // check person with confidence > 90%
//                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
//                    return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
//                }
//                //                self.classificationLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
//                print("Classification:\n" + descriptions.joined(separator: "\n"))
            }
        }
    }
    
    func checkPersonIsTrusted(confidence: Float, name: String) {
        print("\(name) - \(confidence)")
        // person with recognition's confidence more than 90% is trusted
        if confidence > 0.2 {
            print("\(name) - \(confidence * 100)%")
            if classifiedList[name] == nil {
                classifiedList[name] = Date()
                checkin(name: name)
                print("checked in first time")
            } else {
                // check recognition time of one person
                let dateClassified = classifiedList[name]
                if Date().timeIntervalSince(dateClassified!) > kRecognitionTimePeriod {
                    checkin(name: name)
                    print("check in time after")
                }
            }
        }
    }
    
    private func checkin(name: String) {
        checkAppFirstTime()
        thirdPersonLabel.text = secondPersonLabel.text
        secondPersonLabel.text = firstPersonLabel.text
        firstPersonLabel.text = name.uppercased() + " has checked in"
        API.shared.callApi(endpoint: "/time.json", success: { (data) in
            print(data as Any)
        }) { (error) in
            print(error)
        }
    }
    
    private func checkAppFirstTime() {
        if let _ = firstPersonLabel.text {
            firstPersonLabel.isHidden = false
        }
        if let _ = secondPersonLabel.text {
            secondPersonLabel.isHidden = false
        }
        if let _ = thirdPersonLabel.text {
            thirdPersonLabel.isHidden = false
        }
    }
}

