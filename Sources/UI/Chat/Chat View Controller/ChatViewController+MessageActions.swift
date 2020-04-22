//
//  ChatViewController+MessageActions.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 09/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatClient
import StreamChatCore
import RxSwift

extension ChatViewController {
    typealias CopyAction = () -> Void
    
    /// Show message actions when long press on a message cell.
    public struct MessageAction: OptionSet {
        public let rawValue: Int
        
        /// Add reactions.
        public static let reactions = MessageAction(rawValue: 1 << 0)
        /// Reply to a message.
        public static let reply = MessageAction(rawValue: 1 << 1)
        /// Edit an own message.
        public static let edit = MessageAction(rawValue: 1 << 2)
        /// Mute a user of the message.
        public static let muteUser = MessageAction(rawValue: 1 << 3)
        /// Flag a message.
        public static let flagMessage = MessageAction(rawValue: 1 << 4)
        /// Flag a user of the message.
        public static let flagUser = MessageAction(rawValue: 1 << 5)
        /// Ban a user of the message.
        public static let banUser = MessageAction(rawValue: 1 << 6)
        /// Copy text or URL from the message.
        public static let copy = MessageAction(rawValue: 1 << 7)
        /// Delete own message.
        public static let delete = MessageAction(rawValue: 1 << 8)
        
        /// All message actions.
        public static let all: MessageAction = [.reactions,
                                                .reply,
                                                .edit,
                                                .muteUser,
                                                .flagMessage,
                                                .flagUser,
                                                .banUser,
                                                .copy,
                                                .delete]
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    public func defaultActionSheet(from cell: UITableViewCell, for message: Message, locationInView: CGPoint) -> UIAlertController? {
        guard let presenter = presenter else {
            return nil
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if messageActions.contains(.reactions), presenter.channel.config.reactionsEnabled {
            alert.addAction(.init(title: .localized(key: "stream_message_action_reactions"),
                                  style: .default,
                                  handler: { [weak self] _ in
                self?.showReactions(from: cell, in: message, locationInView: locationInView)
            }))
        }
        
        if messageActions.contains(.reply), presenter.canReply {
            alert.addAction(.init(title: .localized(key: "stream_message_action_reply"),
                                  style: .default,
                                  handler: { [weak self] _ in
                self?.showReplies(parentMessage: message)
            }))
        }
        
        if messageActions.contains(.edit), message.canEdit {
            alert.addAction(.init(title: .localized(key: "stream_message_action_edit"),
                                  style: .default,
                                  handler: { [weak self] _ in
                self?.edit(message: message)
            }))
        }
        
        if messageActions.contains(.copy), let copyAction = copyAction(for: message) {
            alert.addAction(.init(title: .localized(key: "stream_message_action_copy"),
                                  style: .default,
                                  handler: { _ in copyAction() }))
        }
        
        if !message.user.isCurrent {
            // Mute.
            if messageActions.contains(.muteUser), presenter.channel.config.mutesEnabled {
                if message.user.isMuted {
                    alert.addAction(.init(title: .localized(key: "stream_message_action_unmute"),
                                          style: .default,
                                          handler: { [weak self] _ in
                        self?.unmute(user: message.user)
                    }))
                } else {
                    alert.addAction(.init(title: .localized(key: "stream_message_action_mute"),
                                          style: .default,
                                          handler: { [weak self] _ in
                        self?.mute(user: message.user)
                    }))
                }
            }
            
            if presenter.channel.config.flagsEnabled {
                // Flag a message.
                if messageActions.contains(.flagMessage) {
                    if message.isFlagged {
                        alert.addAction(.init(title: .localized(key: "stream_message_action_unflag"),
                                              style: .default,
                                              handler: { [weak self] _ in
                            self?.unflag(message: message)
                        }))
                    } else {
                        alert.addAction(.init(title: .localized(key: "stream_message_action_flag"),
                                              style: .destructive,
                                              handler: { [weak self] _ in
                            self?.flag(message: message)
                        }))
                    }
                }
                
                // Flag a user.
                if messageActions.contains(.flagUser) {
                    if message.user.isFlagged {
                        alert.addAction(.init(title: .localized(key: "stream_user_action_unflag"),
                                              style: .default,
                                              handler: { [weak self] _ in
                            self?.unflag(user: message.user)
                        }))
                    } else {
                        alert.addAction(.init(title: .localized(key: "stream_user_action_flag"),
                                              style: .destructive,
                                              handler: { [weak self] _ in
                            self?.flag(user: message.user)
                        }))
                    }
                }
            }
            
            if messageActions.contains(.banUser),
                presenter.channel.banEnabling.isEnabled(for: presenter.channel),
                !presenter.channel.isBanned(message.user) {
                alert.addAction(.init(title: .localized(key: "stream_user_action_ban"),
                                      style: .destructive,
                                      handler: { [weak self] _ in
                    if let channel = self?.presenter?.channel {
                        self?.ban(user: message.user, channel: channel)
                    }
                }))
            }
        }
        
        if messageActions.contains(.delete), message.canDelete {
            alert.addAction(.init(title: .localized(key: "stream_action_delete"),
                                  style: .destructive,
                                  handler: { [weak self] _ in
                self?.conformDeleting(message: message)
            }))
        }
        
        if alert.actions.isEmpty {
            return nil
        }
        
        alert.addAction(.init(title: .localized(key: "stream_action_cancel"),
                              style: .cancel,
                              handler: { _ in }))
        
        if UIDevice.isPad, let popoverPresentationController = alert.popoverPresentationController {
            let cellPositionY = tableView.convert(cell.frame, to: UIScreen.main.coordinateSpace).minY + locationInView.y
            let isAtBottom = cellPositionY > CGFloat.screenHeight * 0.6
            popoverPresentationController.permittedArrowDirections = isAtBottom ? .down : .up
            popoverPresentationController.sourceView = cell
            popoverPresentationController.sourceRect = CGRect(x: locationInView.x,
                                                              y: locationInView.y + (isAtBottom ? -15 : 15),
                                                              width: 0,
                                                              height: 0)
        }
        
        return alert
    }
    
    private func edit(message: Message) {
        composerView.text = message.text
        presenter?.editMessage = message
        composerView.styleState = .edit
        composerView.textView.becomeFirstResponder()
        
        if let composerAddFileContainerView = composerAddFileContainerView {
            composerEditingContainerView.sendToBack(for: [composerAddFileContainerView, composerCommandsContainerView])
        } else {
            composerEditingContainerView.sendToBack(for: [composerCommandsContainerView])
        }
        
        composerEditingContainerView.animate(show: true)
    }
    
    private func copyAction(for message: Message) -> CopyAction? {
        let copyText: String = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var copyURL: URL?
        
        if let first = message.attachments.first, let url = first.url {
            copyURL = url
        }
        
        if !copyText.isEmpty || copyURL != nil {
            return {
                if !copyText.isEmpty {
                    UIPasteboard.general.string = copyText
                } else if let url = copyURL {
                    UIPasteboard.general.url = url
                }
            }
        }
        
        return nil
    }
    
    private func conformDeleting(message: Message) {
        var text: String?
        
        if message.textOrArgs.isEmpty {
            if let attachment = message.attachments.first {
                text = attachment.title
            }
        } else {
            text = message.text.count > 100 ? String(message.text.prefix(100)) + "..." : message.text
        }
        
        let alert = UIAlertController(title: .localized(key: "stream_message_action_delete_confirm"),
                                      message: text,
                                      preferredStyle: .alert)
        
        alert.addAction(.init(title: .localized(key: "stream_action_delete"),
                              style: .destructive,
                              handler: { [weak self] _ in
            if let self = self {
                message.rx.delete().subscribe().disposed(by: self.disposeBag)
            }
        }))
        
        alert.addAction(.init(title: .localized(key: "stream_action_cancel"),
                              style: .cancel,
                              handler: { _ in }))
        
        present(alert, animated: true)
    }
    
    private func mute(user: User) {
        user.rx.mute()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_muted"),
                                            user.name),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unmute(user: User) {
        user.rx.unmute()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_unmuted"),
                                            user.name),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func flag(message: Message) {
        message.rx.flag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_flagged"),
                                            message.textOrArgs),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unflag(message: Message) {
        message.rx.unflag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_unflagged"),
                                            message.textOrArgs),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func flag(user: User) {
        user.rx.flag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_flagged"),
                                            user.name),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unflag(user: User) {
        user.rx.unflag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_unflagged"),
                                            user.name),
                                     backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func ban(user: User, channel: Channel) {
        channel.rx.ban(user: user)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner(String(format: .localized(key: "stream_banner_message_banned"),
                                            user.name), backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Context Menu

@available(iOS 13, *)
extension ChatViewController {
    
    public func tableView(_ tableView: UITableView,
                          contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        guard useContextMenuForActions else {
            return nil
        }
        
        guard let cell = tableView.cellForRow(at: indexPath),
              let message = self.presenter?.items[safe: indexPath.row]?.message else {
                return nil
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else {
                return nil
            }
            
            let locationInView = tableView.convert(point, to: cell)
            return self.createActionsContextMenu(from: cell, for: message, locationInView: locationInView)
        }
    }
    
    public func defaultActionsContextMenu(from cell: UITableViewCell, for message: Message, locationInView: CGPoint) -> UIMenu? {
        guard let presenter = presenter else {
            return nil
        }
        
        var actions = [UIAction]()
        
        if messageActions.contains(.reactions), presenter.channel.config.reactionsEnabled {
            actions.append(UIAction(title: .localized(key: "stream_message_action_reactions"),
                                    image: UIImage(systemName: "smiley")) { [weak self] _ in
                self?.showReactions(from: cell, in: message, locationInView: locationInView)
            })
        }
        
        if messageActions.contains(.reply), presenter.canReply {
            actions.append(UIAction(title: .localized(key: "stream_message_action_reply"),
                                    image: UIImage(systemName: "arrowshape.turn.up.left")) { [weak self] _ in
                self?.showReplies(parentMessage: message)
            })
        }
        
        if messageActions.contains(.edit), message.canEdit {
            actions.append(UIAction(title: .localized(key: "stream_message_action_edit"),
                                    image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.edit(message: message)
            })
        }
        
        if messageActions.contains(.copy), let copyAction = copyAction(for: message) {
            actions.append(UIAction(title: .localized(key: "stream_message_action_copy"),
                                    image: UIImage(systemName: "doc.on.doc")) { _ in copyAction() })
        }
        
        if !message.user.isCurrent {
            // Mute.
            if messageActions.contains(.muteUser), presenter.channel.config.mutesEnabled {
                if message.user.isMuted {
                    actions.append(UIAction(title: .localized(key: "stream_message_action_unmute"),
                                            image: UIImage(systemName: "speaker")) { [weak self] _ in
                        self?.unmute(user: message.user)
                    })
                } else {
                    actions.append(UIAction(title: .localized(key: "stream_message_action_mute"),
                                            image: UIImage(systemName: "speaker.slash")) { [weak self] _ in
                        self?.mute(user: message.user)
                    })
                }
            }
            
            if presenter.channel.config.flagsEnabled {
                // Flag a message.
                if messageActions.contains(.flagMessage) {
                    if message.isFlagged {
                        actions.append(UIAction(title: .localized(key: "stream_message_action_unflag"),
                                                image: UIImage(systemName: "flag.slash")) { [weak self] _ in
                                                    self?.unflag(message: message)
                        })
                    } else {
                        actions.append(UIAction(title: .localized(key: "stream_message_action_flag"),
                                                image: UIImage(systemName: "flag"),
                                                attributes: [.destructive]) { [weak self] _ in
                                                    self?.flag(message: message)
                        })
                    }
                }
                
                // Flag a user.
                if messageActions.contains(.flagUser) {
                    if message.user.isFlagged {
                        actions.append(UIAction(title: .localized(key: "stream_user_action_unflag"),
                                                image: UIImage(systemName: "hand.raised.slash")) { [weak self] _ in
                                                    self?.unflag(user: message.user)
                        })
                    } else {
                        actions.append(UIAction(title: .localized(key: "stream_user_action_flag"),
                                                image: UIImage(systemName: "hand.raised"),
                                                attributes: [.destructive]) { [weak self] _ in
                                                    self?.flag(user: message.user)
                        })
                    }
                }
            }
            
            if messageActions.contains(.banUser),
                presenter.channel.banEnabling.isEnabled(for: presenter.channel),
                !presenter.channel.isBanned(message.user) {
                actions.append(UIAction(title: .localized(key: "stream_user_action_ban"),
                                        image: UIImage(systemName: "exclamationmark.octagon"),
                                        attributes: [.destructive]) { [weak self] _ in
                                            if let channel = self?.presenter?.channel {
                                                self?.ban(user: message.user, channel: channel)
                                            }
                })
            }
        }
        
        if messageActions.contains(.delete), message.canDelete {
            actions.append(UIAction(title: .localized(key: "stream_action_delete"),
                                    image: UIImage(systemName: "trash"),
                                    attributes: [.destructive]) { [weak self] _ in
                                        self?.conformDeleting(message: message)
            })
        }
        
        if actions.isEmpty {
            return nil
        }
        
        view.endEditing(true)
        
        return UIMenu(title: "", children: actions)
    }
}
