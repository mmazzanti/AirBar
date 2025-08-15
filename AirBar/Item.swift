//
//  Item.swift
//  AirBar
//
//  Created by Matteo Mazzanti on 15.08.2025.
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
