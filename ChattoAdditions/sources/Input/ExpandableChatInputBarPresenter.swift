/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation
import UIKit
import Chatto

@objc
public class ExpandableChatInputBarPresenter: NSObject, ChatInputBarPresenter {

    public let chatInputBar: ChatInputBar
    let chatInputItems: [ChatInputItemProtocol]
    let notificationCenter: NotificationCenter

    public weak var viewController: ChatInputBarPresentingController? {
        didSet {
            self.viewController?.setup(inputView: self.chatInputBar)
        }
    }

    public init(chatInputBar: ChatInputBar,
                chatInputItems: [ChatInputItemProtocol],
                chatInputBarAppearance: ChatInputBarAppearance,
                notificationCenter: NotificationCenter = NotificationCenter.default) {

        self.chatInputBar = chatInputBar
        self.chatInputItems = chatInputItems
        self.chatInputBar.setAppearance(chatInputBarAppearance)
        self.notificationCenter = notificationCenter
        super.init()

        self.chatInputBar.presenter = self
        self.chatInputBar.inputItems = self.chatInputItems
        self.notificationCenter.addObserver(self, selector: #selector(keyboardDidChangeFrame), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(handleOrienationDidChangeNotification), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    fileprivate(set) public var focusedItem: ChatInputItemProtocol? {
        willSet {
            self.focusedItem?.selected = false
        }
        didSet {
            self.focusedItem?.selected = true
        }
    }

    fileprivate var shouldIgnoreContainerBottomMarginUpdates: Bool = false
    fileprivate func updateContentContainer(withInputItem inputItem: ChatInputItemProtocol) {
        self.cleanCurrentInputView()
        let responder = self.chatInputBar.textView!
        if inputItem.presentationMode == .keyboard {
            responder.becomeFirstResponder()
        } else if let inputView = inputItem.inputView, let inputPositionController = self.viewController {
            responder.resignFirstResponder()
            self.setup(inputBar: inputView, inContainerOfInputBarController: inputPositionController)
        }
    }

    fileprivate func firstKeyboardInputItem() -> ChatInputItemProtocol? {
        var firstKeyboardInputItem: ChatInputItemProtocol?
        for inputItem in self.chatInputItems where inputItem.presentationMode == .keyboard {
            firstKeyboardInputItem = inputItem
            break
        }
        return firstKeyboardInputItem
    }

    private func cleanCurrentInputView(animated: Bool = false, completion: (() -> Void)? = nil) {
        self.currentInputView?.endEditing(false)
        if animated {
            UIView.animate(withDuration: CATransaction.animationDuration(), animations: {
                self.currentInputView?.alpha = 0.0
            }, completion: { (_) in
                self.currentInputView?.removeFromSuperview()
                completion?()
            })
        } else {
            self.currentInputView?.removeFromSuperview()
            completion?()
        }
    }

    private func setup(inputBar: UIView, inContainerOfInputBarController inputBarController: ChatInputBarPresentingController) {
        self.shouldIgnoreContainerBottomMarginUpdates = true
        inputBarController.changeInputContentBottomMarginWithDefaultAnimation(
            to: self.keyboardHeight
        ) {
            self.shouldIgnoreContainerBottomMarginUpdates = false
        }

        let containerView: InputContainerView = {
            let containerView = InputContainerView()
            containerView.allowsSelfSizing = true
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.contentView = inputBar
            return containerView
        }()
        inputBarController.setup(inputView: containerView)
        self.currentInputView = containerView
    }

    private var lastKnownKeyboardHeight: CGFloat?
    private var keyboardHeight: CGFloat {
        return self.lastKnownKeyboardHeight ?? self.defaultKeyboardHeight
    }
    private var allowListenToChangeFrameEvents = true

    // MARK: Input View

    private weak var currentInputView: InputContainerView?

    private var defaultKeyboardHeight: CGFloat {
        if UIScreen.main.portraitOrientation {
            return UIScreen.main.defaultPortraitKeyboardHeight
        } else {
            return UIScreen.main.defaultLandscapeKeyboardHeight
        }
    }

    private func expandedInputViewHeight(forItem item: ChatInputItemProtocol) -> CGFloat {
        guard let inputPositionController = self.viewController else { return 0.0 }
        return inputPositionController.maximumInputSize.height - item.expandedStateTopMargin
    }

    // MARK: Notifications handling

    @objc
    private func keyboardDidChangeFrame(_ notification: Notification) {
        guard self.allowListenToChangeFrameEvents else { return }
        guard let value = (notification as NSNotification).userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        guard value.cgRectValue.height > 0 else { return }
        self.lastKnownKeyboardHeight = value.cgRectValue.height - self.chatInputBar.bounds.height
    }

    @objc
    private func keyboardWillHide(_ notification: Notification) {
        self.allowListenToChangeFrameEvents = false
    }

    @objc
    private func keyboardWillShow(_ notification: Notification) {
        self.allowListenToChangeFrameEvents = true
    }

    @objc
    private func handleOrienationDidChangeNotification(_ notification: Notification) {
        self.lastKnownKeyboardHeight = nil
        if let currentInputView = self.currentInputView {
            currentInputView.contentHeight = self.keyboardHeight
            self.viewController?.changeInputContentBottomMarginWithDefaultAnimation(
                to: self.keyboardHeight,
                completion: nil
            )
        }
    }

    // MARK: Controllers updates handling

    private func onKeyboardStateDidChange(bottomMargin: CGFloat, keyboardState: KeyboardState) {
        guard let inputPositionController = self.viewController else { return }
        if self.focusedItem == nil || self.focusedItem?.presentationMode == .keyboard {
            inputPositionController.changeInputContentBottomMarginWithoutAnimation(to: bottomMargin, completion: nil)
        } else if let item = self.focusedItem {
            switch keyboardState {
            case .shown, .showing:
                inputPositionController.changeInputContentBottomMarginWithDefaultAnimation(
                    to: self.expandedInputViewHeight(forItem: item),
                    completion: nil
                )
            case .hidden, .hiding:
                inputPositionController.changeInputContentBottomMarginWithDefaultAnimation(
                    to: self.keyboardHeight,
                    completion: nil
                )
            }
        }
    }

    private func onScrollViewDidEndDragging(willDecelerate decelerate: Bool) {
        guard self.shouldProcessScrollViewUpdates() else { return }
        guard let inputPositionController = self.viewController else { return }
        self.shouldIgnoreContainerBottomMarginUpdates = true
        if 3 * inputPositionController.inputContentBottomMargin < self.keyboardHeight {
            let completion: () -> Void = { [weak self] in
                self?.shouldIgnoreContainerBottomMarginUpdates = false
                self?.cleanupFocusedItem(animated: true)
            }
            inputPositionController.changeInputContentBottomMarginWithDefaultAnimation(
                to: 0,
                completion: completion
            )
        } else {
            let completion: () -> Void = { [weak self] in self?.shouldIgnoreContainerBottomMarginUpdates = false }

            inputPositionController.changeInputContentBottomMarginWithDefaultAnimation(
                to: self.keyboardHeight,
                completion: completion
            )
        }
    }

    private func onScrollViewDidScroll(velocity: CGPoint, location: CGPoint) {
        guard self.shouldProcessScrollViewUpdates() else { return }
        self.currentInputView?.endEditing(false)
        guard let inputPositionController = self.viewController else { return }
        if location.y > 0 {
            inputPositionController.changeInputContentBottomMarginWithoutAnimation(
                to: inputPositionController.inputContentBottomMargin - location.y,
                completion: nil
            )
        } else if inputPositionController.inputContentBottomMargin < self.keyboardHeight && velocity.y < 0 {
            inputPositionController.changeInputContentBottomMarginWithoutAnimation(
                to: min(self.keyboardHeight, inputPositionController.inputContentBottomMargin - location.y),
                completion: nil
            )
        }
        if inputPositionController.inputContentBottomMargin == 0 {
            self.cleanupFocusedItem(animated: true)
        }
    }

    private func shouldProcessScrollViewUpdates() -> Bool {
        guard !self.shouldIgnoreContainerBottomMarginUpdates else { return false }
        guard let focusItem = self.focusedItem else { return false }
        guard focusItem.presentationMode != .keyboard else { return false }
        return true
    }

    private func hideContentView(withVelocity velocity: CGPoint) {
        self.shouldIgnoreContainerBottomMarginUpdates = true
        let velocityAwareDuration = min(Double(self.keyboardHeight / velocity.y), CATransaction.animationDuration())

        self.viewController?.changeInputContentBottomMargin(
            to: 0,
            animation: SpringChatInputBarAnimation(
                duration: velocityAwareDuration,
                initialSpringVelocity: velocity.y
            )
        ) { [weak self] in
            self?.shouldIgnoreContainerBottomMarginUpdates = false
            self?.cleanupFocusedItem(animated: true)
        }
    }

    private func cleanupFocusedItem(animated: Bool = false) {
        self.focusedItem = nil
        self.cleanCurrentInputView(animated: animated) {
            self.onDidEndEditing()
        }
    }
}

// MARK: ChatInputBarPresenter
extension ExpandableChatInputBarPresenter {
    public func onDidEndEditing() {
        if self.focusedItem != nil {
            guard self.focusedItem?.presentationMode == .keyboard else { return }
        }
        self.focusedItem = nil
        self.chatInputBar.textView.inputView = nil
        self.chatInputBar.showsTextView = true
        self.chatInputBar.showsSendButton = true
    }

    public func onDidBeginEditing() {
        if self.focusedItem == nil, let item = self.firstKeyboardInputItem() {
            self.focusedItem = item
            self.updateContentContainer(withInputItem: item)
        }
    }

    public func onSendButtonPressed() {
        if let focusedItem = self.focusedItem {
            focusedItem.handleInput(self.chatInputBar.inputText as AnyObject)
        } else if let keyboardItem = self.firstKeyboardInputItem() {
            keyboardItem.handleInput(self.chatInputBar.inputText as AnyObject)
        }
        self.chatInputBar.inputText = ""
    }

    public func onDidReceiveFocusOnItem(_ item: ChatInputItemProtocol) {
        guard item.presentationMode != .none else { return }
        guard item !== self.focusedItem else { return }

        self.focusedItem = item
        self.chatInputBar.showsSendButton = item.showsSendButton
        self.chatInputBar.showsTextView = item.presentationMode == .keyboard
        self.allowListenToChangeFrameEvents = item.presentationMode == .keyboard
        self.updateContentContainer(withInputItem: item)
    }

    public func onViewDidUpdate() { }
}

// MARK: KeyboardEventsHandling
extension ExpandableChatInputBarPresenter: KeyboardUpdatesHandlerDelegate {

    public func didAdjustBottomMargin(to margin: CGFloat, state: KeyboardState) {
        self.onKeyboardStateDidChange(bottomMargin: margin, keyboardState: state)
    }
}

// MARK: ScrollViewEventsHandling
extension ExpandableChatInputBarPresenter: CollectionViewEventsHandling {

    public func onScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let inputPositionController = self.viewController else { return }
        guard let view = scrollView.panGestureRecognizer.view else { return }

        let velocity = scrollView.panGestureRecognizer.velocity(in: view)
        let location = scrollView.panGestureRecognizer.location(in: inputPositionController.inputBarContainer)

        switch scrollView.panGestureRecognizer.state {
        case .changed:
            self.onScrollViewDidScroll(velocity: velocity, location: location)
        case .ended where velocity.y > 0:
            self.hideContentView(withVelocity: velocity)
        default:
            break
        }
    }

    public func onScrollViewDidEndDragging(_ scrollView: UIScrollView, decelerate: Bool) {
        self.onScrollViewDidEndDragging(willDecelerate: decelerate)
    }
}
