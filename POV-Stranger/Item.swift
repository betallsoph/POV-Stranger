//
//  Item.swift
//  POV-Stranger
//
//  Created by An T. Tran on 7/13/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
