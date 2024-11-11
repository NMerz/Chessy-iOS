//
//  PgnView.swift
//  Chessy
//
//  Created by Nathan Merz on 9/15/24.
//

import Foundation
import SwiftUI

struct PgnView: View, Hashable {
    let pgnText: String
    
    var body: some View {
        Text(pgnText)
        Button {
            UIPasteboard.general.string = pgnText
        } label: {
            Text("Copy to clipboard")
        }
        Text("After copying the game to the clipboard, you can import it into any chess engine that accepts PGN like https://www.chess.com/analysis?tab=analysis")
    }
    
    
}
