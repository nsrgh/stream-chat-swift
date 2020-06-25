//
//  UIViewController+ImagePicker.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 03/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import Photos.PHPhotoLibrary

extension ViewController {
    enum ImagePickerError: Error {
        case invalidStatus(PHAuthorizationStatus)
        case sourceTypeNotSupported
        case unknown
    }
    
    typealias ImagePickerCompletion = (Result<PickedImage, ImagePickerError>) -> Void
    
    func showImagePicker(sourceType: UIImagePickerController.SourceType, _ completion: @escaping ImagePickerCompletion) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            completion(.failure(.sourceTypeNotSupported))
            return
        }
        
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.showAuthorizedImagePicker(sourceType: sourceType, completion)
                    } else {
                        completion(.failure(.invalidStatus(status)))
                    }
                }
            }
        case .restricted, .denied:
            completion(.failure(.invalidStatus(status)))
        case .authorized:
            showAuthorizedImagePicker(sourceType: sourceType, completion)
        @unknown default:
            print(#file, #function, #line, "Unknown authorization status: \(status.rawValue)")
            return
        }
    }
    
    private func showAuthorizedImagePicker(sourceType: UIImagePickerController.SourceType,
                                           _ completion: @escaping ImagePickerCompletion) {
        let delegateKey = String(ObjectIdentifier(self).hashValue) + "ImagePickerDelegate"
        let imagePickerViewController = UIImagePickerController()
        imagePickerViewController.sourceType = sourceType
        
        if sourceType != .camera {
            imagePickerViewController.mediaTypes = [.imageFileType]
        }
        
        let delegate = ImagePickerDelegate(completion) {
            objc_setAssociatedObject(self, delegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // Completion is not called when user cancels. This is intended
        }
        
        imagePickerViewController.delegate = delegate
        
        if case .camera = sourceType {
            imagePickerViewController.cameraCaptureMode = .photo
            imagePickerViewController.cameraDevice = .front
            
            if UIImagePickerController.isFlashAvailable(for: .front) {
                imagePickerViewController.cameraFlashMode = .on
            }
        }
        
        objc_setAssociatedObject(self, delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        present(imagePickerViewController, animated: true)
    }
    
    func showImagePickerAlert(for error: ImagePickerError) {
        let title: String
        let message: String
        var actions = [UIAlertAction(title: .localized(key: "stream_action_ok"),
                                     style: .default,
                                     handler: nil)]
        
        switch error {
        case .sourceTypeNotSupported:
            title = .localized(key: "stream_input_library_permission")
            message = .localized(key: "stream_input_library_permission_notdetermined")
        case .invalidStatus(let status):
            title = .localized(key: "stream_input_library_permission")
            actions.insert(UIAlertAction(title: .localized(key: "stream_permission_settings"),
                                         style: .default,
                                         handler: { _ in
                                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(settingsURL)
                                            }}),
                            at: 0)
            
            switch status {
            case .notDetermined:
                message = .localized(key: "stream_input_library_permission_notdetermined")
            case .denied:
                message = .localized(key: "stream_input_library_premission_denied")
            case .restricted:
                message = .localized(key: "stream_input_library_permission_restricted")
            default:
                return
            }
        case .unknown:
            title = .localized(key: "stream_input_library_permission")
            message = .localized(key: "stream_input_library_premission_denied")
        }
        
        showAlert(title: title, message: message, actions: actions)
    }
}

// MARK: - Image Picker Delegate

fileprivate final class ImagePickerDelegate: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    typealias Cancel = () -> Void
    let completion: ViewController.ImagePickerCompletion
    let cancellation: Cancel
    
    init(_ completion: @escaping ViewController.ImagePickerCompletion, cancellation: @escaping Cancel) {
        self.completion = completion
        self.cancellation = cancellation
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        if let pickedImage = PickedImage(info: info) {
            completion(.success(pickedImage))
        } else {
            completion(.failure(.unknown))
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        cancellation()
    }
}
