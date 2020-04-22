//
//  StreamLocalizationManager.swift
//  StreamChatClient
//
//  Created by Nikita Korobeinikov on 22/04/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

public class StreamLocalizationManager {
    
    public static let shared = StreamLocalizationManager()
    
    lazy var supportedLanguageCodes: [String] = {
        return ["en", "de"]
    }()
    
    private init() {}
    
    var currentLanguageCode: String?
    
    public func set(code: String) {
        guard supportedLanguageCodes.contains(where: { $0 == code }) else {
            return
        }
        currentLanguageCode = code
    }
    
    public func localizedBundle(from bundle: Bundle) -> Bundle {
        guard let languageCode = currentLanguageCode, let path = bundle.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: path) else {
                return bundle
        }
        return languageBundle
    }
}
