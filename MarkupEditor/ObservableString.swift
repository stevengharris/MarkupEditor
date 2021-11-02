//
//  ObservableString.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/2/21.
//

import Foundation

public class ObservableString: ObservableObject {
    @Published public var value: String
    
    required public init(_ value: String) {
        self.value = value
    }
    
    public func set(to value: String) {
        self.value = value
    }
    
}
