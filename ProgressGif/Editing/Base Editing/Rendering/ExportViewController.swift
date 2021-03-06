//
//  ExportViewController.swift
//  ProgressGif
//
//  Created by Zheng on 7/21/20.
//

import UIKit
import AVFoundation
import AVKit
import SwiftGifOrigin

class ExportViewController: UIViewController {
    
    var renderingAsset: AVAsset!
    var editingConfiguration: EditableEditingConfiguration!
    var playerURL = URL(fileURLWithPath: "")
    var exportedGifURL = URL(fileURLWithPath: "")
    
    @IBOutlet weak var backgroundBlurView: UIVisualEffectView!
    
    @IBOutlet weak var processingLabel: UILabel!
    
    @IBOutlet weak var playerBaseView: UIView!
    
    @IBOutlet weak var playerBackgroundView: UIView!
    
    @IBOutlet weak var playerBackgroundLeftC: NSLayoutConstraint!
    @IBOutlet weak var playerBackgroundRightC: NSLayoutConstraint!
    @IBOutlet weak var playerBackgroundTopC: NSLayoutConstraint!
    @IBOutlet weak var playerBackgroundBottomC: NSLayoutConstraint!
    
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var progressBaseView: UIView!
    
    @IBOutlet weak var progressStatusLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var segmentIndicator: ANSegmentIndicator!
    
    @IBOutlet weak var exportButtonBaseView: UIView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func cancelButtonPressed(_ sender: Any) {
        if let exportSession = export {
            exportSession.cancelExport()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBOutlet weak var exportButton: UIButton!
    @IBAction func exportButtonPressed(_ sender: Any) {
        
        let shareItems = [exportedGifURL]
        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
        
        /// the following was for testing (the rendered video, not yet converted to gif)
//        let player = AVPlayer(url: playerURL)
//        let playerViewController = AVPlayerViewController()
//        playerViewController.player = player
//        self.present(playerViewController, animated: true) {
//            playerViewController.player!.play()
//        }
    }
    
    var export: AVAssetExportSession?
    
    /// is proportional to the height of the video.
    /// multiply this by the editingConfiguration values
    var unit = CGFloat(1)
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// animate pulsing processing fade in/out
        UIView.animate(withDuration: 0.5, animations: {
            self.processingLabel.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.processingLabel.alpha = 1
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.alpha = 0
        
        processingLabel.alpha = 0
        playerBaseView.layer.cornerRadius = 12
        playerBackgroundView.layer.cornerRadius = 12
        
        playerBaseView.clipsToBounds = true
        exportButton.layer.cornerRadius = 12
        exportButton.alpha = 0
        
        if let urlAsset = renderingAsset as? AVURLAsset {
            render(from: urlAsset, with: editingConfiguration) { exportedURL in
                guard let exportedURL = exportedURL else {
                    return
                }
                self.playerURL = exportedURL
                self.finishedExport()
            }
        }
        
        var settings = ANSegmentIndicatorSettings()
        settings.defaultSegmentColor = UIColor.tertiarySystemBackground
        settings.segmentBorderType = .round
        settings.segmentsCount = 1
        settings.segmentWidth = 16
        settings.animationDuration = 0.1
        settings.segmentColor = UIColor(named: "Yellorange")!
        
        segmentIndicator.settings = settings
    }
    
    func updateProgress(to progress: Float) {
        let progressPercent = progress * 100
        segmentIndicator.updateProgress(percent: Degrees(progressPercent))
        progressLabel.fadeTransition(0.1)
        progressLabel.text = "\(Int(progressPercent))%"
    }
    
    
    /// finished rendering video. Then need to convert to gif.
    func finishedExport() {
        segmentIndicator.updateProgress(percent: 100)
        progressLabel.text = "100%"
        
        progressStatusLabel.fadeTransition(0.6)
        progressStatusLabel.text = "Finishing"
        
        
        var aspectRect = imageView.frame
        if let image = playerURL.generateImage() {
            imageView.image = image
            let adjustedRect = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
            aspectRect = imageView.convert(adjustedRect, to: playerBaseView)
            
            playerBackgroundLeftC.constant = aspectRect.origin.x
            playerBackgroundTopC.constant = aspectRect.origin.y
            playerBackgroundRightC.constant = (playerBaseView.bounds.width - aspectRect.width) / 2
            playerBackgroundBottomC.constant = (playerBaseView.bounds.height - aspectRect.height) / 2
        }
        UIView.animate(withDuration: 0.5, delay: 0.4, options: .curveEaseOut, animations: {
            self.playerBackgroundView.layer.cornerRadius = 0
            self.playerBaseView.layoutIfNeeded()
        }) { _ in
            /// start exporting to gif
            Regift.createGIFFromSource(self.playerURL, startTime: 0, duration: Float(CMTimeGetSeconds(self.renderingAsset.duration)), frameRate: 16) { (url) in
                
                if let gifUrl = url {
                    print("Convert to GIF completed! Export URL: \(gifUrl)")
                    self.finishedConversion(gifURL: gifUrl)
                    self.exportedGifURL = gifUrl
                } else {
                    self.processingLabel.text = "Error"
                }
            }
        }
        
        
    }
    
    func finishedConversion(gifURL: URL) {
        processingLabel.layer.removeAllAnimations()
        
        do {
            let imageData = try Data(contentsOf: gifURL)
            self.imageView.image = UIImage.gif(data: imageData)
        } catch {
            print("error reading gif file: \(error)")
        }
        
        UIView.animate(withDuration: 0.6, animations: {
            self.processingLabel.alpha = 0
            self.cancelButton.alpha = 0
            self.segmentIndicator.alpha = 0
            self.progressLabel.alpha = 0
            self.progressStatusLabel.alpha = 0
        }) { _ in
            
            self.processingLabel.text = "Here you go!"
            
            UIView.animate(withDuration: 0.6, animations: {
                self.processingLabel.alpha = 1
                self.imageView.alpha = 1
            })
            
            self.exportButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 1, delay: 0.4, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: .curveLinear, animations: {
                self.exportButton.alpha = 1
                self.exportButton.transform = CGAffineTransform.identity
            }, completion: nil)
        }
        
    }
}
