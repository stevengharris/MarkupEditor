//
//  MarkupDivStructure.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/17/24.
//

import Foundation

/// MarkupDivStructure is a class that holds the divs and buttongroups used by the MarkupEditor.
public class MarkupDivStructure {
    public var divs: [HtmlDivHolder] = []
    private var divsById: [String : HtmlDivHolder] = [:]
    private var buttonsById: [String : HtmlButton] = [:]
    private var targetIdsByDivId: [String : String] = [:]
    
    public init() {}
    
    public func reset() {
        divs = []
        divsById = [:]
        buttonsById = [:]
        targetIdsByDivId = [:]
    }
    
    public func add(_ div: HtmlDivHolder) {
        divs.append(div)
        divsById[div.id] = div
        if let targetId = div.targetId {
            targetIdsByDivId[div.id] = targetId
        }
        if let buttonGroup = div.buttonGroup {
            divsById[buttonGroup.id] = div  // Identify the enclosing div for a ButtonGroup
        }
        for button in div.buttons {
            buttonsById[button.id] = button
        }
    }
    
    public func remove(_ div: HtmlDivHolder) {
        guard let index = divs.firstIndex(where: {existing in existing.id == div.id }) else { return }
        divs.remove(at: index)
        divsById.removeValue(forKey: div.id)
        targetIdsByDivId.removeValue(forKey: div.id)
        for button in div.buttons {
            buttonsById.removeValue(forKey: button.id)
        }
    }
    
    public func button(for buttonId: String) -> HtmlButton? {
        buttonsById[buttonId]
    }
    
    public func div(forDivId divId: String) -> HtmlDivHolder? {
        divsById[divId]
    }
    
    public func targetId(forDivId divId: String) -> String? {
        targetIdsByDivId[divId]
    }
    
}
