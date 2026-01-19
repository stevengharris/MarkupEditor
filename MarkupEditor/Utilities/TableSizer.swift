//
//  TableSizer.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/12/21.
//  Copyright © 2021, 2022 Steven Harris. All rights reserved.
//

import SwiftUI

/// The TableSizer shows a grid for the user to choose a table size to create.
///
/// A difficulty of the TableSizer is how to deal with both mouse and touch devices.
/// In particular, the hover-based highlighting is really nice when you have a mouse,
/// but otherwise, you have to drag to see a gesture. When you're hovering to set
/// the table size, you want to use a positive gesture to indicate you are done, and
/// this is a tap that occurs in the TableSizer grid.
///
/// If you are on a touch device without a mouse, the hover doesn't do anything, so
/// rows and cols remain at 0 until you drag. If you are dragging on a touch device,
/// then when you stop dragging, you want the table insertion to happen, so you don't
/// need to tap. You can also drag with the mouse, in which case it behaves like the
/// standard drag behavior, dismissing and inserting the table when you stop dragging.
///
/// The rows and cols are set to 0 to indicate the table should not be sized. This
/// happens when the mouse or drag location is outside of the TableSizer grid, or
/// (somewhat by definition) the tap is outside of the TableSizer grid.
struct TableSizer: View {
    let maxRows: Int = 6
    let maxCols: Int = 8
    let cellSize: CGFloat = 16
    let sizedColor = Color.accentColor.opacity(0.2)
    //TODO: A hack, but I cannot find a way for the padding on the popover to look right in both environments
    #if targetEnvironment(macCatalyst)
    let topPadding: CGFloat = 8
    let bottomPadding: CGFloat = 8
    #else
    let topPadding: CGFloat = 0
    let bottomPadding: CGFloat = 20
    #endif
    @Binding var rows: Int
    @Binding var cols: Int
    @Binding var showing: Bool
    @State var dragged: Bool = false
    @State private var backgroundWidth = CGFloat.zero
    @State private var backgroundHeight = CGFloat.zero
    
    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                dragged = true
                let location = value.location
                let colCount = (location.x / cellSize).rounded(.awayFromZero)
                let rowCount  = (location.y / cellSize).rounded(.awayFromZero)
                cols = Int(colCount)
                rows = Int(rowCount)
                if (cols > maxCols || rows > maxRows) {
                    rows = 0
                    cols = 0
                }
                setBackground()
            }
            .onEnded { _ in
                showing.toggle()
            }
        let tapGesture = TapGesture()
            .onEnded {
                showing.toggle()
            }
        VStack(spacing: 0) {
            if rows > 0 && cols > 0 {
                Text("\(rows)x\(cols) table").foregroundColor(Color.black)
            } else {
                Text("Size the table").foregroundColor(Color.black)
            }
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .foregroundColor(sizedColor)
                    .frame(width: backgroundWidth, height: backgroundHeight)
                VStack(spacing: 0) {
                    ForEach(0..<maxRows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<maxCols, id: \.self) { col in
                                Rectangle()
                                    .frame(width: cellSize, height: cellSize)
                                    .border(Color.accentColor)
                                    .background(Color.clear)
                                    .foregroundColor(Color.clear)
                                    .contentShape(Rectangle())
                                    .onHover { hovering in
                                        if hovering && !dragged {
                                            rows = row + 1
                                            cols = col + 1
                                            if (cols > maxCols || rows > maxRows) {
                                                rows = 0
                                                cols = 0
                                            }
                                            setBackground()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .highPriorityGesture(tapGesture)
            .onHover { hovering in
                // Let the user know visually that the table won't be sized.
                // Guard by dragged, because onHover can occur after onEnded,
                // which results in no table being created.
                if !dragged {
                    rows = 0
                    cols = 0
                }
                setBackground()
            }
            .gesture(dragGesture)
        }
        .padding(EdgeInsets(top: topPadding, leading: 8, bottom: bottomPadding, trailing: 8))
    }
    
    init(rows: Binding<Int>, cols: Binding<Int>, showing: Binding<Bool>) {
        // The TableSizer should always open with zero rows and columns since it is only used to
        // create a new table
        _rows = rows
        _cols = cols
        _showing = showing
    }
    
    private func setBackground() {
        backgroundWidth = CGFloat(cols) * cellSize
        backgroundHeight = CGFloat(rows) * cellSize
    }
}

struct TableSizer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HStack {
                TableSizer(rows: .constant(3), cols: .constant(3), showing: .constant(true))
                Spacer()
            }
            Spacer()
        }
    }
}

