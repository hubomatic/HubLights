//
//  MicroVectorDocument.swift
//  MicroVector
//
//  Created by Marc Prud'hommeaux on 2/12/21.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var svgMicroVector: UTType {
        UTType(importedAs: "net.hubomatic.MicroVector.svg")
    }
}

/// https://en.wikipedia.org/wiki/Scalable_Vector_Graphics#Example
let sampleSVGText = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg width="391" height="391" viewBox="-70.5 -70.5 391 391" xmlns="http://www.w3.org/2000/svg">
<rect fill="#fff" stroke="#000" x="-70" y="-70" width="390" height="390"/>
<g opacity="0.8">
    <rect x="25" y="25" width="200" height="200" fill="green" stroke-width="4" stroke="pink" />
    <circle cx="125" cy="125" r="75" fill="orange" />
    <polyline points="50,150 50,200 200,200 200,100" stroke="red" stroke-width="4" fill="none" />
    <line x1="50" y1="50" x2="200" y2="200" stroke="blue" stroke-width="4" />
</g>
</svg>
"""

struct MicroVectorDocument: FileDocument {
    var svgText: String

    init(svgText: String = sampleSVGText) {
        self.svgText = svgText
    }

    static var readableContentTypes: [UTType] { [.svgMicroVector] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        svgText = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = svgText.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
