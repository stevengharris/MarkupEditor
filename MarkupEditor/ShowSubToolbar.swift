//
//  ShowSubToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 6/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// The observable object containing the type of SubToolbar to show, or nil for none
public class ShowSubToolbar: ObservableObject {
    @Published public var type: SubToolbar.ToolbarType?
    
    public init() {}
}
