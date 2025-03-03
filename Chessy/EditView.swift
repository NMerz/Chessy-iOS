//
//  EditView.swift
//  Chessy
//
//  Created by Nathan Merz on 9/19/24.
//

import Foundation
import SwiftUI



struct EditView: View, Hashable {
    static func == (lhs: EditView, rhs: EditView) -> Bool {
        return lhs.movePredictions == rhs.movePredictions
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(movePredictions)
    }
    
    @State var movePredictions: MovePredictions
    let columns = [GridItem(spacing: .zero), GridItem(spacing: .zero), GridItem(spacing: .zero)]

    @State var processing = false
    @State var navPath: Binding<NavigationPath>
    @State var combinedResults: [String] = []
    @State var imageUrl: URL
    @State var showErrorMessage = false
    
        
    @State private var result = String("Result: ")
  
     @FocusState  var focusedField: Int?
 
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let remainingCount = max((movePredictions.openai.lastIndex(where: { moveParts in
                    moveParts[0] != nil
                }) ?? 0) * 2 - combinedResults.count, 0)
                VStack {
                    Text("OCR results:").onAppear {
                        Task {
                            processing = true
                            do {
                                combinedResults = try await Poster.postFor([String].self, request: URLRequest(url: URL (string: "https://play-chess-965053369291.us-central1.run.app")!), postContent: movePredictions)
                                print(combinedResults)
                                processing = false
                            } catch let err {
                                print(err)
                            }
                        }
                    }
                    Text("Estimated moves left after current: " + String(describing: remainingCount))
                    Button(action: {
                        var pgnText = ""
                        for resultIndex in combinedResults.indices {
                            if resultIndex % 2 == 0 {
                                pgnText += String(format: "%d. %@", Int(resultIndex / 2 + 1), combinedResults[resultIndex])
                            } else {
                                pgnText += String(format: " %@ ", combinedResults[resultIndex])
                            }
                        }
                        navPath.wrappedValue.append(PgnView(pgnText: pgnText))
                    }, label: {
                        Text("Done Editing").bold().font(.system(size: 15)).foregroundStyle(Color(uiColor: .label)).fixedSize().frame(height: 45)
                    }).tint(.blue).buttonStyle(BorderedProminentButtonStyle())
                    ScrollView {
                        LazyVGrid(columns: columns) {
                            Text("#")
                            Text("White").frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                            Text("Black").frame(maxWidth: .infinity, alignment: .leading)
                            /// combinedResults.forEach { result in }
                            ForEach(0 ..< Int(truncatingIfNeeded: (combinedResults.count + 1) / 2), id: \.self) { turnNumber in
                                //                    if result % 2 == 0 {
                                Text((turnNumber + 1).description)
                                //                    }
                                
                                ForEach(0 ..< 2) { offset in
                                    let currentMove = turnNumber * 2 + offset

                                    VStack {
                                        if (currentMove < combinedResults.count) {
                                            if movePredictions.cell_bounds.count > currentMove {
                                                let ciImage = CIImage(contentsOf: imageUrl)!
                                                let xMax = movePredictions.cell_bounds[currentMove].map({vertex in  vertex.x}).reduce(0) { partialResult, currentMax in
                                                    return max(partialResult, currentMax)
                                                }
                                                let xMin = movePredictions.cell_bounds[currentMove].map({vertex in  vertex.x}).reduce(Int(ciImage.extent.width)) { partialResult, currentMin in
                                                    return min(partialResult, currentMin)
                                                }
                                                let yMax = movePredictions.cell_bounds[currentMove].map({vertex in  vertex.y}).reduce(0) { partialResult, currentMax in
                                                    return max(partialResult, currentMax)
                                                }
                                                let yMin = movePredictions.cell_bounds[currentMove].map({vertex in  vertex.y}).reduce(Int(ciImage.extent.height)) { partialResult, currentMin in
                                                    return min(partialResult, currentMin)
                                                }
                                                let width = 200 //JWM  max(xMax - xMin, 1)
                                                let height = 100 //JWM  max(yMax - yMin, 1)
                                                //                                    let cropped = CIImage(contentsOf: imageUrl)!.cropped(to: CGRect(x: xMin, y: yMin, width: xMax - xMin, height: yMax - yMin))
                                                Image(uiImage: UIImage(cgImage: (UIImage(contentsOfFile: imageUrl.path())?.cgImage!.cropping(to: CGRect(x: xMin, y: max(yMin - Int(Double(height) * 0.1), 0), width: width, height: Int(Double(height) * 1.3)))!)!)).resizable().frame(width: geometry.size.width / 3, height: CGFloat(geometry.size.width / 3.0) * CGFloat(height) / CGFloat(width)).onAppear {
                                                    print(ciImage.extent.width, ciImage.extent.height)
                                                    print(geometry.size.width / 3, CGFloat(geometry.size.width / 3.0) * CGFloat(height) / CGFloat(width))
                                                    print(CGFloat(geometry.size.width / 3.0), CGFloat(height), CGFloat(width))
                                                }
                                            } else {
                                                Text("")
                                            }
                                        }
                                        if (currentMove < combinedResults.count) {
                                            TextField("", text: $combinedResults[currentMove])
                                                .background(combinedResults[currentMove] == "" ? Color.red : Color.clear)
                                                //.onChange(of: isFocused) { isFocused in
                                                         // this will get called after the delay
                                                     //  }
                                                       .onAppear {
                                                         // key part: delay setting isFocused until after some-internal-iOS setup
                                                         DispatchQueue.main.asyncAfter(deadline: .now()+0.7) {
                                                              focusedField = combinedResults.count - 1
                                                         }
                                                       }
                                            
                                            
                                                .onChange(of: combinedResults[currentMove], {
                                                if combinedResults[currentMove].contains( try! Regex("^([QRBKN])?([a-h]?)(x?)([a-h])([0-9])(\\+?)#?$")) {
                                                    showErrorMessage = false
                                                    print("JWM - we have a move that looks like a move, but is it valid?")
                                                    
                                                    Task {
                                                        let oldCount = combinedResults.count
                                                        movePredictions.past_moves = combinedResults
                                                        processing = true
                                                        do {
                                                            combinedResults = try await Poster.postFor([String].self, request: URLRequest(url: URL (string: "https://play-chess-965053369291.us-central1.run.app")!), postContent: movePredictions)
//                                                            if combinedResults.count == oldCount && remainingCount != 0 {
//                                                                withAnimation (.linear(duration: 0.1)) {
//                                                                    showErrorMessage = true
//                                                                }
//                                                                Task {
//                                                                    try await Task.sleep(nanoseconds: 5_000_000_000)
//                                                                    showErrorMessage = false
//                                                                }
//                                                            }
                                                            print(combinedResults)
                                                            processing = false
                                                        } catch let err {
                                                            if combinedResults.count == oldCount {
                                                                withAnimation (.linear(duration: 0.1)) {
                                                                    showErrorMessage = true
                                                                }
                                                                Task {
                                                                    try await Task.sleep(nanoseconds: 5_000_000_000)
                                                                    showErrorMessage = false
                                                                }
                                                            }
                                                            print(err)
                                                        }
                                                    }
                                                }
                                            })
                                             
                                                .font(.system(size: 24)).autocorrectionDisabled()
                                                .focused($focusedField, equals: currentMove)

                                        }
                                    }
                                }
                                Color.primary.frame(height: 2.0)
                                Color.primary.frame(height: 2.0)
                                Color.primary.frame(height: 2.0)
                            }
                        }
                    }.defaultScrollAnchor(.bottom)
                    

                        VStack {
                            
                            let column1Names = "PNBRQK\u{232B}".map{ String($0) }
                            let column2Names = "abcdefgh".map{ String($0) }
                            let column3Names = "12345678".map{ String($0) }
                            let column4Names = ["x", "+", "#", "O-O", "O-O-O"]

                            let allColumns = [ column1Names , column2Names , column3Names , column4Names]
                            ForEach(allColumns, id: \.self) { currentColumn in
                                HStack {
                                    
                                    ForEach( currentColumn, id: \.self) { buttonName in
                                        
                                        HStack {
                                            @State var myColor = Color.white
                                            // let buttonName = "T"
                                            let length = buttonName.count
                                            let buttonWidthBase =  (length > 1 ) ? CGFloat(length * 22) : CGFloat(25)
                                            let buttonWidth = (buttonName == "\u{232B}") ? CGFloat(70) : buttonWidthBase
                                           // $focusedField = combinedResults.count
                                            Button(action: {
                                                //  colSelected = buttonName
                                                
                                                //  withAnimation (.linear(duration: 0.1)){
                                                //       myColor = Color.gray
                                                //   }
                                                withAnimation (.linear(duration: 1.3)){
                                                    myColor = Color.white
                                                }
                                                if let newIndex = focusedField {
                                            
                                                    if (combinedResults.count > 0) {
                                                        
                                                        if (buttonName == "\u{232B}") {
                                                            if (combinedResults[newIndex].count > 0 ){
                                                                combinedResults[newIndex] = String( combinedResults[newIndex].dropLast() )
                                                            }
                                                        } else {
                                                            combinedResults[newIndex] += buttonName
                                                        }
                                                    }
                                                }
                                                
                                            }) {
                                                
                                                Text(buttonName)
                                                    .foregroundStyle(.black )
                                                    .font(.system(size: 21)).fixedSize()  //30
                                                //.onTapGesture {
                                                
                                                // }
                                            }
                                            .frame(width: buttonWidth, height: 15, alignment: .center)
                                            .padding(.top, 10)
                                            .padding(.bottom, 10)
                                            .padding(.leading, 10)
                                            .padding(.trailing, 0)
                                            .buttonStyle(.borderedProminent)
                                            .tint(myColor)
                                            .animation(.default, value: true)
                                            // .animation(.default, value: colSelected == buttonName)
                                            
                                        }
                                    }
                                }
                            }
                        }
                        // .containerRelativeFrame([.horizontal, .vertical])
                        .frame(maxWidth: .infinity, maxHeight: 210)
                        .background(Color.gray  .ignoresSafeArea())
               ////     }////  zstsck

                    
                    
                    
                    
                    
                    
                    
                    
                    //  ButtonCellView(buttonName: buttonName, colSelected: $col1Selected, result: $result )
                    //  $combinedResults[currentMove]
 //                   Text("JWM button here")
                         

                        
                        
                        
                        
                        
                   /// }////
                   
                }
                if showErrorMessage {
                    VStack {
                        RoundedRectangle(cornerRadius: 10).frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.1).opacity(0.7).foregroundStyle(.black).overlay {
                            VStack {
                                Text(String("Game is not valid")).font(Font.system(size: 18)).foregroundStyle(.white).bold()
                                Text("Please verify all past inputs").font(Font.system(size: 14)).foregroundStyle(.white)
                            }
                        }
                        Spacer().frame(height: geometry.size.height * 0.2)
                    }
                }
            }
        }
        
    }
    
    
}

// ButtonCellView(buttonName: "T",  result: $combinedResults, focused: focusedField  )
/*
struct ButtonCellView: View {

    let buttonName: String
    // @Binding var colSelected: Optional<String>
   //  let fieldNumber: Int
    @Binding var result: [String]
  //  @Binding var focusedField: Int?
     @Binding var focused: Int?
   @State var myColor = Color.white

    var body: some View {
 
        HStack {

            let length = buttonName.count
            let buttonWidthBase =  (length > 1 ) ? CGFloat(length * 22) : CGFloat(25)
            let buttonWidth = (buttonName == "\u{232B}") ? CGFloat(70) : buttonWidthBase
            Button(action: {
                
               // print (focusedField)
               //  colSelected = buttonName
                
              //  withAnimation (.linear(duration: 0.1)){
             //       myColor = Color.gray
             //   }
                withAnimation (.linear(duration: 1.3)){
                    myColor = Color.white
                }
                if let newIndex = focused {
                    // list.items[newIndex].name += "XVX"
            
                    if (buttonName == "\u{232B}") {
                        if (result[newIndex].count > 0 ){
                            result[newIndex] = String( result[newIndex].dropLast() )
                        }
                    } else {
                        result[newIndex] += buttonName
                    }
                }
                /*
                if (buttonName == "\u{232B}") {
                    if (result.count > 0 ){
                        result = String( result.dropLast() )
                    }
                } else {
                    result += buttonName
                }
                 */
                
            }) {
                
                Text(buttonName)
                    .foregroundStyle(.black )
                    .font(.system(size: 21)).fixedSize()  //30
                //.onTapGesture {
                
                // }
            }
            .frame(width: buttonWidth, height: 15, alignment: .center)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .padding(.leading, 10)
            .padding(.trailing, 0)
            .buttonStyle(.borderedProminent)
            .tint(myColor)
            .animation(.default, value: true)
            // .animation(.default, value: colSelected == buttonName)
            
        }

    }
}
*/
