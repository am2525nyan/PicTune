//
//  StampViewModel.swift
//  PIcTune
//
//  Created by saki on 2024/02/05.
//

import SwiftUI

class SelectedImageManager: ObservableObject {
    @Published var selectedImage: String?

    static let shared = SelectedImageManager()
    private init() {}
}
