//
//  String+Localize.swift
//  StreamChatClient
//
//  Created by Nikita Korobeinikov on 22/04/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

final class ChatCoreModule {
    static let bundle = Bundle(for: ChatCoreModule.self)
}

extension String {
    
    static func localized(key: String) -> String {
        NSLocalizedString(key,
                          tableName: nil,
                          bundle: StreamLocalizationManager.shared.localizedBundle(from: ChatCoreModule.bundle),
                          value: "",
                          comment: "")
    }
    
}
