//
//  MarkupDivStructure.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/17/24.
//

import Foundation

class MarkupDivStructure {
    var divs: [MarkupDiv] = []
    var buttonGroups: [MarkupButtonGroup] = []
    var actionsByButtonId: [String : ()->Void] = [:]
    
    func add(_ div: MarkupDiv) {
        divs.append(div)
    }
    
    func remove(_ div: MarkupDiv) {
        guard let index = divs.firstIndex(where: {existing in existing.id == div.id }) else { return }
        divs.remove(at: index)
    }
    
    func add(_ button: MarkupButton, in divId: String) {
        add([button], in: divId)
    }
    
    func add(_ buttons: [MarkupButton], in divId: String) {
        let buttonGroup = MarkupButtonGroup(in: divId, buttons: buttons)
        buttonGroups.append(buttonGroup)
        for button in buttons {
            actionsByButtonId[button.id] = button.action
        }
    }
    
    func action(for buttonId: String) -> (()->Void)? {
        actionsByButtonId[buttonId]
    }
    
}
