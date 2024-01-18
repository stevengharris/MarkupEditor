//
//  MarkupDivStructure.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/17/24.
//

import Foundation

public class MarkupDivStructure {
    public var divs: [HtmlDivHolder] = []
    public var buttonGroups: [HtmlButtonGroup] = []
    private var buttonsById: [String : HtmlButton] = [:]
    
    public init() {}
    
    public func add(_ div: HtmlDivHolder) {
        divs.append(div)
    }
    
    public func remove(_ div: HtmlDivHolder) {
        guard let index = divs.firstIndex(where: {existing in existing.id == div.id }) else { return }
        divs.remove(at: index)
    }
    
    public func add(_ button: HtmlButton, in divId: String) {
        add([button], in: divId)
    }
    
    public func add(_ buttons: [HtmlButton], in divId: String) {
        let buttonGroup = HtmlButtonGroup(in: divId, buttons: buttons)
        buttonGroups.append(buttonGroup)
        for button in buttons {
            buttonsById[button.id] = button
        }
    }
    
    public func button(for buttonId: String) -> HtmlButton? {
        buttonsById[buttonId]
    }
    
}
