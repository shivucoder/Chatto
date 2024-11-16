//
// Copyright (c) Badoo Trading Limited, 2010-present. All rights reserved.
//

import Foundation

public typealias BoolBlock = (Bool) -> Void

public protocol ChatMessagesViewModelProtocol: AnyObject {
    var chatItems: [ChatItemProtocol] { get }
    var delegate: ChatDataSourceDelegateProtocol? { get set }
    var hasMoreNext: Bool { get }
    var hasMorePrevious: Bool { get }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion: BoolBlock)
    func loadPrevious()
    func loadNext()
}
