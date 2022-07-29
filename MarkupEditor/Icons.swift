//
//  Icons.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/17/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

struct ColoredEdge {
    static let borderColor: Color = Color.primary
    static let borderThickness: CGFloat = 2
    static let outlineColor: Color = Color.secondary
    static let outlineThickness: CGFloat = 1
}

//MARK: Table Icons

struct TableCell: View {
    @State var width: CGFloat
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var deleted: Bool = false
    @State var leadingColor: Color?
    @State var leadingThickness: CGFloat?
    @State var trailingColor: Color
    @State var trailingThickness: CGFloat
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: width, height: height)
                .foregroundColor(selected ? Color.accentColor.opacity(0.2) : Color(UIColor.systemBackground))
            if let leadingColor = leadingColor, let leadingThickness = leadingThickness {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: height))
                }
                .stroke(leadingColor, lineWidth: leadingThickness)
            }
            Path { path in
                path.move(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: height))
            }
            .stroke(trailingColor, lineWidth: trailingThickness)
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
    @State var border: TableBorder = .none
    var body: some View {
        GeometryReader() { geometry in
            HStack(spacing: 0) {
                ForEach(0..<cols, id: \.self) { col in
                    let select = selected ? true : col == selectCol
                    let delete = deleted ? true : deleteCols?.contains(col) ?? false
                    TableCell(
                        width: geometry.size.width / CGFloat(cols),
                        height: height,
                        selected: select,
                        deleted: delete,
                        leadingColor: col == 0 ? colColor(for: col, edge: .leading) : nil,
                        leadingThickness: col == 0 ? colThickness(for: col, edge: .leading) : nil,
                        trailingColor: colColor(for: col),
                        trailingThickness: colThickness(for: col))
                }
            }
        }
    }
    
    /// Return the color for the trailing edge (unless overridden) of a cell at col
    private func colColor(for col: Int, edge: Edge = .trailing) -> Color {
        var color: Color
        switch edge {
        case .leading:
            switch border {
            case .none:
                color = ColoredEdge.outlineColor
            default:
                color = col == 0 ? ColoredEdge.borderColor : ColoredEdge.outlineColor
            }
        case .trailing:
            switch border {
            case .outer, .header:
                if isHeader {
                    color = col == cols - 1 ? ColoredEdge.borderColor : Color.clear
                } else {
                    color = col == cols - 1 ? ColoredEdge.borderColor : ColoredEdge.outlineColor
                }
            case .cell:
                if isHeader {
                    color = col == cols - 1 ? ColoredEdge.borderColor : Color.clear
                } else {
                    color = ColoredEdge.borderColor
                }
            case .none:
                if isHeader {
                    color = col == cols - 1 ? ColoredEdge.outlineColor : Color.clear
                } else {
                    color = ColoredEdge.outlineColor
                }
            }
        default:
            color = ColoredEdge.outlineColor
        }
        return color
    }

    /// Return the thickness for the trailing edge (unless overridden) of a cell at col
    private func colThickness(for col: Int, edge: Edge = .trailing) -> CGFloat {
        var thickness: CGFloat
        switch edge {
        case .leading:
            switch border {
            case .none:
                thickness = ColoredEdge.outlineThickness
            default:
                thickness = col == 0 ? ColoredEdge.borderThickness : ColoredEdge.outlineThickness
            }
        case .trailing:
            switch border {
            case .outer, .header:
                if isHeader {
                    thickness = col == cols - 1 ? ColoredEdge.borderThickness : 0
                } else {
                    thickness = col == cols - 1 ? ColoredEdge.borderThickness : ColoredEdge.outlineThickness
                }
            case .cell:
                if isHeader {
                    thickness = col == cols - 1 ? ColoredEdge.borderThickness : 0
                } else {
                    thickness = ColoredEdge.borderThickness
                }
            case .none:
                if isHeader {
                    thickness = col == cols - 1 ? ColoredEdge.outlineThickness : 0
                } else {
                    thickness = ColoredEdge.outlineThickness
                }
            }
        default:
            thickness = ColoredEdge.outlineThickness
        }
        return thickness
    }
    
}

struct TableIcon: View {
    @State var rows: Int = 3
    @State var cols: Int = 3
    @State var inset: CGFloat = 3
    @State var selectRow: Int? = nil
    @State var selectCol: Int? = nil
    @State var withHeader: Bool = false
    @State var deleteRows: [Int]? = nil
    @State var deleteCols: [Int]? = nil
    @State var border: TableBorder = .none
    var body: some View {
        GeometryReader() { geometry in
            let rowHeight = geometry.size.height / CGFloat(rows)
            let rowWidth = geometry.size.width
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    ZStack(alignment: .top) {
                        // Draw the line at the top row of the table if needed
                        if (row == 0) {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: rowWidth, y: 0))
                            }
                            .stroke(rowColor(for: row, edge: .top), lineWidth: rowThickness(for: row, edge: .top))
                            .zIndex(0.5)
                        }
                        TableRow(
                            cols: cols,
                            height: rowHeight,
                            selected: row == selectRow,
                            selectCol: selectCol,
                            deleted: deleteRows?.contains(row) ?? false,
                            deleteCols: deleteCols,
                            isHeader: withHeader ? (row == 0) : false,
                            border: border
                        )
                        // Always draw the line at the bottom of each row
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: rowWidth, y: 0))
                        }
                        .offset(CGSize(width: 0, height: rowHeight))
                        .stroke(rowColor(for: row), lineWidth: rowThickness(for: row))
                        .zIndex(0.5)
                    }
                    
                }
            }
        }
        .padding([.all], inset)
    }
    
    /// Return the color for the bottom edge (unless overridden) of a row
    private func rowColor(for row: Int, edge: Edge = .bottom) -> Color {
        var color: Color
        switch edge {
        case .top:
            switch border {
            case .none:
                color = ColoredEdge.outlineColor
            default:
                if row == 0 {
                    color = ColoredEdge.borderColor
                } else {
                    color = ColoredEdge.outlineColor
                }
            }
        case .bottom:
            switch border {
            case .outer:
                if row == rows - 1 {
                    color = ColoredEdge.borderColor
                } else {
                    color = ColoredEdge.outlineColor
                }
            case .header:
                if row == 0 || row == rows - 1 {
                    color = ColoredEdge.borderColor
                } else {
                    color = ColoredEdge.outlineColor
                }
            case .cell:
                color = ColoredEdge.borderColor
            case .none:
                color = ColoredEdge.outlineColor
            }
        default:
            color = ColoredEdge.outlineColor
        }
        return color
    }
    
    /// Return the thickness for the bottom edge (unless overridden) of a row
    private func rowThickness(for row: Int, edge: Edge = .bottom) -> CGFloat {
        var thickness: CGFloat
        switch edge {
        case .top:
            switch border {
            case .none:
                thickness = ColoredEdge.outlineThickness
            default:
                if row == 0 {
                    thickness = ColoredEdge.borderThickness
                } else {
                    thickness = ColoredEdge.outlineThickness
                }
            }
        case .bottom:
            switch border {
            case .outer:
                if row == rows - 1 {
                    thickness = ColoredEdge.borderThickness
                } else {
                    thickness = ColoredEdge.outlineThickness
                }
            case .header:
                if row == 0 || row == rows - 1 {
                    thickness = ColoredEdge.borderThickness
                } else {
                    thickness = ColoredEdge.outlineThickness
                }
            case .cell:
                thickness = ColoredEdge.borderThickness
            case .none:
                thickness = ColoredEdge.outlineThickness
            }
        default:
            thickness = ColoredEdge.outlineThickness
        }
        return thickness
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
    var border: TableBorder = .none
    var body: some View {
        TableIcon(rows: 3, cols: 3, withHeader: true, border: border)
    }
    
    init(_ border: TableBorder) {
        self.border = border
    }
}

struct TableIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HStack(alignment: .top) {
                TableIcon()
                    .frame(width: 30, height: 30)
                CreateTable()
                    .frame(width: 30, height: 30)
                Divider()
                Group {
                    AddHeader()
                        .frame(width: 30, height: 30)
                    AddRow(direction: .after)
                        .frame(width: 30, height: 30)
                    AddRow(direction: .before)
                        .frame(width: 30, height: 30)
                    AddCol(direction: .after)
                        .frame(width: 30, height: 30)
                    AddCol(direction: .before)
                        .frame(width: 30, height: 30)
                    DeleteTable()
                        .frame(width: 30, height: 30)
                }
                Divider()
                Group {
                    BorderIcon(.cell)
                        .frame(width: 30, height: 30)
                    BorderIcon(.header)
                        .frame(width: 30, height: 30)
                    BorderIcon(.outer)
                        .frame(width: 30, height: 30)
                    BorderIcon(.none)
                        .frame(width: 30, height: 30)
                }
                Spacer()
            }
            Spacer()
        }
    }
}
