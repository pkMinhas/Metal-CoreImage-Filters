//
//  ViewController.swift
//  MetalFilterDemo
//
//  Created by Preet Minhas on 30/11/21.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var lightnessSlider: UISlider!
    @IBOutlet weak var satSlider: UISlider!
    @IBOutlet weak var hueSlider: UISlider!
    
    //Test image credits: Photo by David Pisnoy on Unsplash (https://unsplash.com/photos/46juD4zY1XA)
    let srcImage = UIImage(named: "test")!
    
    //the filter object.
    let filter = HslFilter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = srcImage
        filter.inputImage = CIImage(cgImage: srcImage.cgImage!)
        
        //ui defaults
        hueSlider.value = 0.5
        satSlider.value = 0.5
        lightnessSlider.value = 0.5
    }

    @IBAction func sliderChanged(_ sender: UISlider) {
        //slider mid is unity point, i.e, the multiplier value is 1 when slider is in the middle
        let value = sender.value * 2
        if sender == hueSlider {
            filter.hFactor = value
        } else if sender == satSlider {
            filter.sFactor = value
        } else if sender == lightnessSlider {
            filter.lFactor = value
        }
        
        //render onto the image view
        if let outputImage = filter.outputImage {
            imageView.image = UIImage(ciImage: outputImage)
        }
    }
    
}

