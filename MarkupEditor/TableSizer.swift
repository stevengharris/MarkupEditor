//
//  TableSizer.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/12/21.
//

import SwiftUI

struct TableSizer: View {
    let maxRows: Int = 8
    let maxCols: Int = 10
    let cellSize: CGFloat = 16
    @Binding var rows: Int
    @Binding var cols: Int
    @Binding var showing: Bool
    @Binding var tapped: Bool
    var body: some View {
        VStack(spacing: 0) {
            if tapped {
                Text("\(rows)x\(cols) table").foregroundColor(Color.black)
            } else {
                Text("Size the table").foregroundColor(Color.black)
            }
            ForEach(0..<maxRows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<maxCols, id: \.self) { col in
                        Rectangle()
                            .frame(width: cellSize, height: cellSize)
                            .border(Color.accentColor)
                            .background(Color(UIColor.systemBackground))
                            .foregroundColor(row < rows && col < cols ? Color.accentColor.opacity(0.2) : Color(UIColor.systemBackground))
                            .onTapGesture(count: 1, perform: {
                                tapped = true
                                showing.toggle()
                            })
                            .onHover(perform: { hovering in
                                if hovering && tapped {
                                    rows = row + 1
                                    cols = col + 1
                                }
                            })
                    }
                }
            }
        }
        .onHover(perform: { hovering in
            // We track if we're outside the TableSizer so we know if it was dismissed rather than tapped
            // This is because we never get a tap gesture if we tap outside of the popover
            tapped = hovering
        })
        .padding(8)
    }
    
    init(rows: Binding<Int>, cols: Binding<Int>, showing: Binding<Bool>, tapped: Binding<Bool>) {
        _rows = rows
        _cols = cols
        _showing = showing
        _tapped = tapped
    }
}
