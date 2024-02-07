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
    private var focusIdsByDivId: [String : String] = [:]
    private var buttonGroupIdsByFocusId: [String : String] = [:]
    
    public init() {}
    
    public func reset() {
        divs = []
        divsById = [:]
        buttonsById = [:]
        focusIdsByDivId = [:]
        buttonGroupIdsByFocusId = [:]
    }
    
    public func add(_ div: HtmlDivHolder) {
        divs.append(div)
        divsById[div.id] = div
        if let focusId = div.focusId {
            focusIdsByDivId[div.id] = focusId
        }
        if let buttonGroup = div.buttonGroup {
            divsById[buttonGroup.id] = buttonGroup
            if let focusId = buttonGroup.focusId {
                buttonGroupIdsByFocusId[focusId] = buttonGroup.id
            }
        }
        for button in div.buttons {
            buttonsById[button.id] = button
        }
    }
    
    public func remove(_ div: HtmlDivHolder) {
        guard let index = divs.firstIndex(where: {existing in existing.id == div.id }) else { return }
        divs.remove(at: index)
        divsById.removeValue(forKey: div.id)
        focusIdsByDivId.removeValue(forKey: div.id)
        buttonGroupIdsByFocusId.removeValue(forKey: div.id)
        for button in div.buttons {
            buttonsById.removeValue(forKey: button.id)
        }
    }
    
    public func button(forButtonId buttonId: String) -> HtmlButton? {
        buttonsById[buttonId]
    }
    
    public func div(forDivId divId: String?) -> HtmlDivHolder? {
        guard let divId else { return nil }
        return divsById[divId]
    }
    
    public func focusId(forDivId divId: String) -> String? {
        focusIdsByDivId[divId]
    }
    
    public func buttonGroupId(forDivId divId: String?) -> String? {
        guard let divId else { return nil }
        return buttonGroupIdsByFocusId[divId]
    }
    
}
