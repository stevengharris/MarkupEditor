//
//  TableIcons.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/17/21.
//

import SwiftUI

//MARK:- Link Icons

struct RemoveLink: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Image.forToolbar(systemName: "link")
            Image(systemName: "minus.circle.fill")
                .foregroundColor(Color.red)
                .background(Color.black)
                .clipShape(Circle())
                .offset(CGSize(width: -8, height: 2))
                .font(Font.system(size: 8).weight(.bold))
                .zIndex(1)
        }
    }
}

//MARK:- Table Icons

struct TableCell: View {
    @State var width: CGFloat
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var deleted: Bool = false
    @State var borderEdges: [Edge] = []
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: width, height: height)
                .foregroundColor(selected ? Color.accentColor.opacity(0.2) : Color(UIColor.systemBackground))
            ForEach(borderEdges, id: \.self) { edge in
                switch edge {
                case .top:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: width, y: 0))
                    }
                    .stroke(Color.accentColor)
                case .bottom:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .stroke(Color.accentColor)
                case .leading:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: height))
                    }
                    .stroke(Color.accentColor)
                case .trailing:
                    Path { path in
                        path.move(to: CGPoint(x: width, y: 0))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .stroke(Color.accentColor)
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
    @State var deleteCol: Int? = nil
    @State var isHeader: Bool = false
    var body: some View {
        GeometryReader() { geometry in
            HStack(spacing: 0) {
                ForEach(0..<cols, id: \.self) { col in
                    let select = selected ? true : col == selectCol
                    let delete = deleted ? true : col == deleteCol
                    let trailingOnly = isHeader && col == cols - 1
                    let none = isHeader && cols > 2 && col > 0 && col < cols - 1
                    let both = !isHeader && col == cols - 1
                    // Each row draws the vertical lines of its cells; the creator of the row draws the horizontal ones
                    // Each cell always draws its leading edge unless:
                    //  1. It is not in the header and it's the last column, in which case it draws both leading and trailing
                    //  2. It is in the header and it is in > the first column. In this case:
                    //      2.1 If it is in between the first and last columns, it draws neither leading nor trailing edges
                    //      2.2 If it is the last column, it draws the trailing edge
                    // In any event, in case it's not obvious, we need a TableCell.
                    if trailingOnly {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [.trailing])
                    } else if both {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [.leading, .trailing])
                    } else if none {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete)
                    } else {
                        TableCell(width: geometry.size.width / CGFloat(cols), height: height, selected: select, deleted: delete, borderEdges: [.leading])
                    }
                }
            }
        }
    }
}

struct TableIcon: View {
    @State var rows: Int
    @State var cols: Int
    @State var inset: CGFloat = 3
    @State var selectRow: Int? = nil
    @State var selectCol: Int? = nil
    @State var withHeader: Bool = false
    @State var deleteRow: Int? = nil
    @State var deleteCol: Int? = nil
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
                            deleted: row == deleteRow,
                            deleteCol: deleteCol,
                            isHeader: withHeader ? (row == 0) : false
                        )
                        if row == 0 {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: rowWidth, y: 0))
                            }
                            .stroke(Color.accentColor)
                            .zIndex(0.5)
                        }
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: rowWidth, y: 0))
                        }
                        .offset(CGSize(width: 0, height: rowHeight))
                        .stroke(Color.accentColor)
                        .zIndex(0.5)
                    }
                    
                }
            }
        }
        .padding([.all], inset)
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
        TableIcon(rows: 3, cols: 3, selectRow: 1, deleteRow: 1)
    }
}

struct DeleteCol: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, selectCol: 1, deleteCol: 1)
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

struct TableIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TableIcon(rows: 3, cols: 4)
        }
        .frame(width: 30, height: 30)
    }
}
