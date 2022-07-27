//
//  Icons.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/17/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

struct ColoredEdge: Identifiable {
    let id = UUID()
    let edge: Edge
    let color: Color
}

//MARK: Table Icons

struct TableCell: View {
    @State var width: CGFloat
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var deleted: Bool = false
    @State var borderEdges: [ColoredEdge] = []
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: width, height: height)
                .foregroundColor(selected ? Color.accentColor.opacity(0.2) : Color(UIColor.systemBackground))
            ForEach(borderEdges, id: \.id) { edge in
                switch edge.edge {
                case .top:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: width, y: 0))
                    }
                    .stroke(edge.color)
                case .bottom:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .stroke(edge.color)
                case .leading:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: height))
                    }
                    .stroke(edge.color)
                case .trailing:
                    Path { path in
                        path.move(to: CGPoint(x: width, y: 0))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .stroke(edge.color)
                }
            }
            if deleted {
                Image(systemName: "xmark")
                    .foregroundColor(Color.red)
                    .font(Font.system(size: 6).weight(.bold))
                    .zIndex(1)
            }
        }
    }
}

struct TableRow: View {
    @State var cols: Int
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var selectCol: Int? = nil
    @State var deleted: Bool = false
    @State var deleteCols: [Int]? = nil
    @State var isHeader: Bool = false
    @State var borders: TableBorders = .none
    let outlineColor = Color.secondary
    let borderColor = Color.primary
    var body: some View {
        GeometryReader() { geometry in
            HStack(spacing: 0) {
                ForEach(0..<cols, id: \.self) { col in
                    let select = selected ? true : col == selectCol
                    let delete = deleted ? true : deleteCols?.contains(col) ?? false
                    let drawLeading = col == 0
                    let leadingColor = borders != .none ? borderColor : outlineColor
                    let drawTrailing = !isHeader || (isHeader && col == cols - 1)
                    let trailingColor = separatorColor(for: col)
                    if (drawLeading && drawTrailing) {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [ColoredEdge(edge: .leading, color: leadingColor), ColoredEdge(edge: .trailing, color: trailingColor)])
                    } else if (drawLeading) {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [ColoredEdge(edge: .leading, color: leadingColor)])
                    } else if (drawTrailing) {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [ColoredEdge(edge: .trailing, color: trailingColor)])
                    } else {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [])
                    }
                }
            }
        }
    }
    
    private func separatorColor(for col: Int) -> Color {
        var color: Color
        switch borders {
        case .outer, .header:
            if col == cols - 1 {
                color = borderColor
            } else {
                color = outlineColor
            }
        case .cell:
            color = borderColor
        case .none:
            color = outlineColor
        }
        return color
    }
}

struct TableIcon: View {
    @State var rows: Int
    @State var cols: Int
    @State var inset: CGFloat = 3
    @State var selectRow: Int? = nil
    @State var selectCol: Int? = nil
    @State var withHeader: Bool = false
    @State var deleteRows: [Int]? = nil
    @State var deleteCols: [Int]? = nil
    @State var borders: TableBorders = .none
    let outlineColor: Color = Color.secondary
    let borderColor: Color = Color.primary
    var body: some View {
        GeometryReader() { geometry in
            let rowHeight = geometry.size.height / CGFloat(rows)
            let rowWidth = geometry.size.width
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    ZStack(alignment: .top) {
                        TableRow(
                            cols: cols,
                            height: rowHeight,
                            selected: row == selectRow,
                            selectCol: selectCol,
                            deleted: deleteRows?.contains(row) ?? false,
                            deleteCols: deleteCols,
                            isHeader: withHeader ? (row == 0) : false,
                            borders: borders
                        )
                        // Draw the line at the top row of the table if needed
                        if row == 0 {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: rowWidth, y: 0))
                            }
                            .stroke(borders != .none ? borderColor : outlineColor)
                            .zIndex(0.5)
                        }
                        // Always draw a separator at the bottom of each row
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: rowWidth, y: 0))
                        }
                        .offset(CGSize(width: 0, height: rowHeight))
                        .stroke(separatorColor(for: row))
                        .zIndex(0.5)
                    }
                    
                }
            }
        }
        .padding([.all], inset)
    }
    
    private func separatorColor(for row: Int) -> Color {
        var color: Color
        switch borders {
        case .outer:
            if row == rows - 1 {
                color = borderColor
            } else {
                color = outlineColor
            }
        case .header:
            if row == 0 || row == rows - 1 {
                color = borderColor
            } else {
                color = outlineColor
            }
        case .cell:
            color = borderColor
        case .none:
            color = outlineColor
        }
        return color
    }
}

struct AddRow: View {
    @State var direction: TableDirection
    var body: some View {
        VStack(spacing: -6) {
            if direction == .after {
                ZStack(alignment: .bottom) {
                    TableIcon(rows: 3, cols: 3, selectRow: 2)
                    Image(systemName: "arrow.down")
                        .offset(CGSize(width: 0, height: -4))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                }
            } else {
                ZStack(alignment: .top) {
                    Image(systemName: "arrow.up")
                        .offset(CGSize(width: 0, height: 4))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                    TableIcon(rows: 3, cols: 3, selectRow: 0)
                }
            }
        }
    }
}

struct AddCol: View {
    @State var direction: TableDirection
    var body: some View {
        HStack(spacing: -6) {
            if direction == .after {
                ZStack(alignment: .trailing) {
                    TableIcon(rows: 3, cols: 3, selectCol: 2)
                    Image(systemName: "arrow.right")
                        .offset(CGSize(width: -4, height: 0))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                }
            } else {
                ZStack(alignment: .leading) {
                    Image(systemName: "arrow.left")
                        .offset(CGSize(width: 4, height: 0))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                            .zIndex(1)
                    TableIcon(rows: 3, cols: 3, selectCol: 0)
                }
            }
        }
    }
}

struct AddHeader: View {
    @State var rows: Int
    @State var cols: Int
    @State var inset: CGFloat = 2
    var body: some View {
        ZStack(alignment: .top) {
            TableIcon(rows: 3, cols: 3, selectRow: 0, withHeader: true)
            Image(systemName: "arrow.up")
                .offset(CGSize(width: 0, height: 4))
                .foregroundColor(Color.red)
                .font(Font.system(size: 12).weight(.bold))
                .zIndex(1)
        }
    }
}

struct DeleteRow: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, selectRow: 1, deleteRows: [1])
    }
}

struct DeleteCol: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, selectCol: 1, deleteCols: [1])
    }
}

struct DeleteTable: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, deleteRows: [0, 1, 2])
    }
}

struct CreateTable: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TableIcon(rows: 3, cols: 3, selectRow: 2, selectCol: 2)
            Image(systemName: "arrow.down.forward")
                .offset(CGSize(width: -4, height: -4))
                .foregroundColor(Color.red)
                .font(Font.system(size: 12).weight(.bold))
                .zIndex(1)
        }
    }
}

struct BorderIcon: View {
    var borders: TableBorders = .none
    var body: some View {
        TableIcon(rows: 3, cols: 3, withHeader: true, borders: borders)
    }
    
    init(_ borders: TableBorders) {
        self.borders = borders
    }
}

struct TableIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TableIcon(rows: 3, cols: 4)
        }
        .frame(width: 30, height: 30)
    }
}
