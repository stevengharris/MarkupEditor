//
//  TableIcons.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/17/21.
//

import SwiftUI

struct TableCell: View {
    @State var width: CGFloat
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var deleted: Bool = false
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: width, height: height)
                .foregroundColor(selected ? Color.accentColor.opacity(0.2) : Color(UIColor.systemBackground))
                .border(Color.accentColor)
            if deleted {
                Image(systemName: "xmark")
                    .foregroundColor(Color.red)
                    .font(Font.system(size: 6).weight(.bold))
                    .zIndex(1)
            }
        }
    }
}

struct TableHeader: View {
    @State var height: CGFloat
    @State var selected: Bool = false
    var body: some View {
        GeometryReader() { geometry in
            Rectangle()
                .frame(width: geometry.size.width, height: height)
                .foregroundColor(Color.accentColor.opacity(0.2))
                .border(Color.accentColor)
        }
    }
}

struct TableRow: View {
    @State var cellCount: Int
    @State var height: CGFloat
    @State var selected: Bool = false
    @State var selectCol: Int? = nil
    @State var deleted: Bool = false
    @State var deleteCol: Int? = nil
    var body: some View {
        GeometryReader() { geometry in
            HStack(spacing: 0) {
                ForEach(0..<cellCount, id: \.self) { cell in
                    let select = selected ? true : cell == selectCol
                    let delete = deleted ? true : cell == deleteCol
                    TableCell(width: geometry.size.width / CGFloat(cellCount), height: height, selected: select, deleted: delete)
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
            let buttonHeight = geometry.size.height
            let rowsPlusHeader = rows + (withHeader ? 1 : 0)
            VStack(spacing: 0) {
                if withHeader {
                    TableHeader(height: buttonHeight, selected: true)
                }
                ForEach(0..<rows, id: \.self) { row in
                    TableRow(
                        cellCount: cols,
                        height: buttonHeight / CGFloat(rowsPlusHeader),
                        selected: row == selectRow,
                        selectCol: selectCol,
                        deleted: row == deleteRow,
                        deleteCol: deleteCol
                    )
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
            TableIcon(rows: 2, cols: 3, withHeader: true)
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

struct TableIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TableIcon(rows: 3, cols: 4)
        }
        .frame(width: 30, height: 30)
    }
}
