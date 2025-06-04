//
//  friend.swift
//  sample
//
//  Created by Takuya M on 2025/06/04.
//

import Foundation
import SwiftData

@Model
class Friend {
    var name : String
    var birthday : Date
    
    init(name: String, birthday: Date) {
        self.name = name
        self.birthday = birthday
    }
    
    var isBirthdayToday: Bool {
        Calendar.current.isDateInToday(birthday)
    }
}
