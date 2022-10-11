//===--- DiagnosticExtensions.swift ---------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftDiagnostics
import SwiftSyntax

extension FixIt {
  init(message: StaticParserFixIt, changes: Changes) {
    self.init(message: message as FixItMessage, changes: changes)
  }

  public init(message: FixItMessage, changes: [Changes]) {
    self.init(message: message, changes: FixIt.Changes(combining: changes))
  }

  init(message: StaticParserFixIt, changes: [Changes]) {
    self.init(message: message as FixItMessage, changes: FixIt.Changes(combining: changes))
  }
}

extension FixIt.Changes {
  /// Replaced a present node with a missing node
  static func makeMissing(node: TokenSyntax) -> Self {
    assert(node.presence == .present)
    var changes = [
      FixIt.Change.replace(
        oldNode: Syntax(node),
        newNode: Syntax(TokenSyntax(node.tokenKind, leadingTrivia: [], trailingTrivia: [], presence: .missing))
      )
    ]
    if !node.leadingTrivia.isEmpty, let nextToken = node.nextToken(viewMode: .sourceAccurate), !nextToken.leadingTrivia.contains(where: { $0.isNewline }) {
      changes.append(.replaceLeadingTrivia(token: nextToken, newTrivia: node.leadingTrivia))
    }
    return FixIt.Changes(changes: changes)
  }

  /// Make a node present. If `leadingTrivia` or `trailingTrivia` is specified,
  /// override the default leading/trailing trivia inferred from `BasicFormat`.
  static func makePresent<T: SyntaxProtocol>(
    node: T,
    leadingTrivia: Trivia? = nil,
    trailingTrivia: Trivia? = nil
  ) -> Self {
    var presentNode = PresentMaker().visit(Syntax(node))
    if let leadingTrivia = leadingTrivia {
      presentNode = presentNode.withLeadingTrivia(leadingTrivia)
    }
    if let trailingTrivia = trailingTrivia {
      presentNode = presentNode.withTrailingTrivia(trailingTrivia)
    }
    return [.replace(
      oldNode: Syntax(node),
      newNode: Syntax(presentNode)
    )]
  }

  /// Makes the `token` present, moving it in front of the previous token's trivia.
  static func makePresentBeforeTrivia(token: TokenSyntax) -> Self {
    if let previousToken = token.previousToken(viewMode: .sourceAccurate) {
      var presentToken = PresentMaker().visit(token).as(TokenSyntax.self)!
      if !previousToken.trailingTrivia.isEmpty {
        presentToken = presentToken.withTrailingTrivia(previousToken.trailingTrivia)
      }
      return [
        .replaceTrailingTrivia(token: previousToken, newTrivia: []),
        .replace(oldNode: Syntax(token), newNode: Syntax(presentToken)),
      ]
    } else {
      return .makePresent(node: token)
    }
  }
}
