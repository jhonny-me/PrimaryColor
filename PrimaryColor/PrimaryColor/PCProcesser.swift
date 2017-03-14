//
//  PCProcesser.swift
//  PrimaryColor
//
//  Created by Johnny Gu on 08/03/2017.
//  Copyright © 2017 Johnny Gu. All rights reserved.
//

import UIKit

struct PCOptions: OptionSet {
    var rawValue: Int
    
    static let onlyBrightColors = PCOptions(rawValue: 1<<0)
    static let onlyDarkColors = PCOptions(rawValue: 1<<1)
    static let onlyDistinctColors = PCOptions(rawValue: 1<<2)
    static let orderByBrightness = PCOptions(rawValue: 1<<3)
    static let orderByDarkness = PCOptions(rawValue: 1<<4)
    static let avoidWhite = PCOptions(rawValue: 1<<5)
    static let avoidBlack = PCOptions(rawValue: 1<<6)
    
    static let defaultMaxOption: PCOptions = [.onlyBrightColors]
}

protocol PrimaryColorProtocol {
    func extractColors(from image: UIImage, using options: PCOptions, completion:@escaping ([UIColor]) -> Void)
    func extractColors(from image: UIImage, using options: PCOptions, avoid colors: [UIColor], completion:@escaping ([UIColor]) -> Void)
    func extractBrightColors(from image: UIImage, completion:@escaping ([UIColor]) -> Void)
    func extractDarkColors(from image: UIImage, completion:@escaping ([UIColor]) -> Void)
    func extractMainColor(from image: UIImage, completion:@escaping (UIColor) -> Void)
}

struct PCProcesser {
    static let colorCubeResolution = 30
    static let brightThreshold = 0.6
    static let darkThreshold = 0.4
    static let distictThreshold = 0.2
    let processQueue = DispatchQueue.init(label: "com.wiredcraft.primarycolor.pcprocesser.processqueue")
    var images: [UIImage] = []
}

extension PCProcesser {
    init(with image: UIImage) {
        self.images = [image]
    }
    init(with images: [UIImage]) {
        self.images = images
    }
    func start(completion: @escaping ([[UIColor]]) -> Void) {
        
    }
}

extension PCProcesser: PrimaryColorProtocol {
    func extractColors(from image: UIImage, using options: PCOptions , avoid colors: [UIColor], completion: @escaping ([UIColor]) -> Void) {
        processQueue.async {
            var colorCubes = self.findPrimaryColors(from: image)
            if options.contains(.onlyDistinctColors) {
                colorCubes = self.filterDistictColors(colorCubes: colorCubes, threshold: PCProcesser.distictThreshold)
            }
            if options.contains(.avoidWhite) {
                colorCubes = self.filterColors(colorCubes: colorCubes, from: UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 1))
            }
            if options.contains(.avoidBlack) {
                colorCubes = self.filterColors(colorCubes: colorCubes, from: UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            }
            colors.forEach({ colorCubes = self.filterColors(colorCubes: colorCubes, from: $0) })
            if options.contains(.orderByDarkness) {
                colorCubes.sort { return $0.brightness < $1.brightness }
            }
            if options.contains(.orderByBrightness) {
                colorCubes.sort { return $0.brightness > $1.brightness }
            }
            DispatchQueue.main.async {
                completion(colorCubes.map{$0.color})
            }
        }
    }
    
    func extractColors(from image: UIImage, using options: PCOptions = .defaultMaxOption , completion: @escaping ([UIColor]) -> Void) {
        extractColors(from: image, using: options, avoid: [], completion: completion)
    }
    
    func extractMainColor(from image: UIImage, completion:@escaping (UIColor) -> Void) {
        extractColors(from: image) { colors in
            completion(colors.first!)
        }
    }
    
    func extractBrightColors(from image: UIImage, completion:@escaping ([UIColor]) -> Void) {
        extractColors(from: image, using: [.onlyBrightColors, .orderByBrightness], avoid: [], completion: completion)
    }
    
    func extractDarkColors(from image: UIImage, completion:@escaping ([UIColor]) -> Void) {
        extractColors(from: image, using: [.onlyDarkColors, .orderByDarkness], avoid: [], completion: completion)
    }
    
    fileprivate func findPrimaryColors(from image: UIImage, using options: PCOptions = .defaultMaxOption) -> [ColorCube] {
        guard let rawDatas = getRawData(from: image) else {
            return []
        }
        var maxColorsFound: [ColorCube] = []
        // init color cube array
        var cubes = Array<ColorCube>.init(repeating: ColorCube(), count: PCProcesser.colorCubeResolution*PCProcesser.colorCubeResolution*PCProcesser.colorCubeResolution)
        for i in stride(from: 0, to: rawDatas.count, by: 4) {
            let red = Double(rawDatas[i]) / 255.0
            let green = Double(rawDatas[i+1]) / 255.0
            let blue = Double(rawDatas[i+2]) / 255.0
            
            if options.contains(.onlyBrightColors) {
                if red < PCProcesser.brightThreshold
                && green < PCProcesser.brightThreshold
                && blue < PCProcesser.brightThreshold {
                    continue
                }
            } else if options.contains(.onlyDarkColors) {
                if red > PCProcesser.darkThreshold
                || green > PCProcesser.darkThreshold
                || blue > PCProcesser.darkThreshold {
                    continue
                }
            }
            
            let cubeIndex = index(red, green, blue)
            cubes[cubeIndex].hitCount += 1
            cubes[cubeIndex].redAll += red
            cubes[cubeIndex].greenAll += green
            cubes[cubeIndex].blueAll += blue
        }
        
        for i in 0..<PCProcesser.colorCubeResolution {
            for j in 0..<PCProcesser.colorCubeResolution {
                for k in 0..<PCProcesser.colorCubeResolution {
                    let cube = cubes[index(i, j, k)]
                    if cube.hitCount == 0 { continue }
                    var isCurrentMax = true
                    for cubeIndex in 0..<ColorCube.nearbyIndexes.count {
                        
                        let redIndex = i + ColorCube.nearbyIndexes[cubeIndex][0]
                        let greenIndex = j + ColorCube.nearbyIndexes[cubeIndex][1]
                        let blueIndex = k + ColorCube.nearbyIndexes[cubeIndex][2]
                        
                        if redIndex < 0 || greenIndex < 0 || blueIndex < 0 || redIndex >= PCProcesser.colorCubeResolution || greenIndex >= PCProcesser.colorCubeResolution || blueIndex >= PCProcesser.colorCubeResolution { continue }
                        
                        if cubes[index(redIndex, greenIndex, blueIndex)].hitCount > cube.hitCount {
                            isCurrentMax = false
                            break
                        }
                    }
                    guard isCurrentMax else { continue }
                    maxColorsFound.append(cube)
                }
            }
        }
        return maxColorsFound.sorted().reversed()
    }
    
    fileprivate func filterDistictColors(colorCubes: [ColorCube], threshold: Double) -> [ColorCube] {
        var newColorCubes: [ColorCube] = []
        for i in 0..<colorCubes.count {
            let colorCube = colorCubes[i]
            var isCurrentDistinct = true
            for j in 0..<i {
                let red = colorCube.redAvg - colorCubes[j].redAvg
                let green = colorCube.greenAvg - colorCubes[j].blueAvg
                let blue = colorCube.blueAvg - colorCubes[j].blueAvg
                let delta = sqrt(red*red + green*green + blue*blue)
                if delta < threshold {
                    isCurrentDistinct = false
                    break
                }
            }
            guard isCurrentDistinct else { continue }
            newColorCubes.append(colorCube)
        }
        return newColorCubes
    }
    
    fileprivate func filterColors(colorCubes: [ColorCube], from closeColor: UIColor) -> [ColorCube] {
        guard let colorComponent = closeColor.cgColor.components else { return [] }
        var newColorCubes: [ColorCube] = []
        for i in 0..<colorCubes.count {
            let colorCube = colorCubes[i]
            let red = Double(colorComponent[0]) - colorCube.redAvg
            let green = Double(colorComponent[1]) - colorCube.greenAvg
            let blue = Double(colorComponent[2]) - colorCube.blueAvg
            let delta = sqrt(red*red + green*green + blue*blue)
            if delta < 0.5 {
                newColorCubes.append(colorCube)
            }
        }
        return newColorCubes
    }
    
    fileprivate func getRawData(from image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        let height = cgImage.height
        let width = cgImage.width
        
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRaw = bytesPerPixel * width
        let bytesAllocated = bytesPerRaw * height
        var rawDatas = [UInt8](repeating: 0, count: bytesAllocated)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext.init(data: &rawDatas, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRaw, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return rawDatas
    }
}

fileprivate struct ColorCube {
    var hitCount = 0
    var redAll: Double = 0
    var greenAll: Double = 0
    var blueAll: Double = 0
    static let nearbyIndexes: [[Int]] = [
        [ 0, 0, 0],
        [ 0, 0, 1],
        [ 0, 0,-1],
        
        [ 0, 1, 0],
        [ 0, 1, 1],
        [ 0, 1,-1],
        
        [ 0,-1, 0],
        [ 0,-1, 1],
        [ 0,-1,-1],
        
        [ 1, 0, 0],
        [ 1, 0, 1],
        [ 1, 0,-1],
        
        [ 1, 1, 0],
        [ 1, 1, 1],
        [ 1, 1,-1],
        
        [ 1,-1, 0],
        [ 1,-1, 1],
        [ 1,-1,-1],
        
        [-1, 0, 0],
        [-1, 0, 1],
        [-1, 0,-1],
        
        [-1, 1, 0],
        [-1, 1, 1],
        [-1, 1,-1],
        
        [-1,-1, 0],
        [-1,-1, 1],
        [-1,-1,-1]
    ]
}

extension ColorCube: Equatable, Comparable {
    var redAvg: Double {
        return redAll/Double(hitCount)
    }
    var greenAvg: Double {
        return greenAll/Double(hitCount)
    }
    var blueAvg: Double {
        return blueAll/Double(hitCount)
    }
    var brightness: Double {
        return max(redAvg, greenAvg, blueAvg)
    }
    var color: UIColor {
        return UIColor(red: CGFloat(redAvg), green: CGFloat(greenAvg), blue: CGFloat(blueAvg), alpha: 1)
    }
}

fileprivate func ==(lhs: ColorCube, rhs: ColorCube) -> Bool {
    return lhs.hitCount == rhs.hitCount
}
fileprivate func >(lhs: ColorCube, rhs: ColorCube) -> Bool {
    return lhs.hitCount > rhs.hitCount
}
fileprivate func <(lhs: ColorCube, rhs: ColorCube) -> Bool {
    return lhs.hitCount < rhs.hitCount
}

fileprivate func index(_ red: Double, _ green: Double, _ blue: Double) -> Int {
    let colorIndex = { (color: Double) in
        return Int(color * Double(PCProcesser.colorCubeResolution - 1))
    }
    let redIndex = colorIndex(red)
    let greenIndex = colorIndex(green)
    let blueIndex = colorIndex(blue)
    
    return index(redIndex, greenIndex, blueIndex)
}

fileprivate func index(_ redIndex: Int, _ greenIndex: Int, _ blueIndex: Int) -> Int {
    return redIndex + greenIndex * PCProcesser.colorCubeResolution + blueIndex * PCProcesser.colorCubeResolution * PCProcesser.colorCubeResolution
}
