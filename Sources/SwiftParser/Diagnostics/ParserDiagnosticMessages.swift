//===--- ParserDiagnosticKinds.swift --------------------------------------===//
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
@_spi(RawSyntax) import SwiftSyntax

let diagnosticDomain: String = "SwiftParser"

/// A error diagnostic whose ID is determined by the diagnostic's type.
public protocol ParserError: DiagnosticMessage {
  var diagnosticID: MessageID { get }
}

public extension ParserError {
  static var diagnosticID: MessageID {
    return MessageID(domain: diagnosticDomain, id: "\(self)")
  }

  var diagnosticID: MessageID {
    return Self.diagnosticID
  }

  var severity: DiagnosticSeverity {
    return .error
  }
}

public protocol ParserNote: NoteMessage {
  var fixItID: MessageID { get }
}

public extension ParserNote {
  static var fixItID: MessageID {
    return MessageID(domain: diagnosticDomain, id: "\(self)")
  }

  var fixItID: MessageID {
    return Self.fixItID
  }
}

public protocol ParserFixIt: FixItMessage {
  var fixItID: MessageID { get }
}

public extension ParserFixIt {
  static var fixItID: MessageID {
    return MessageID(domain: diagnosticDomain, id: "\(self)")
  }

  var fixItID: MessageID {
    return Self.fixItID
  }
}

// MARK: - Errors (please sort alphabetically)

/// Please order the cases in this enum alphabetically by case name.
public enum StaticParserError: String, DiagnosticMessage {
  case allStatmentsInSwitchMustBeCoveredByCase = "all statements inside a switch must be covered by a 'case' or 'default' label"
  case consecutiveDeclarationsOnSameLine = "consecutive declarations on a line must be separated by ';'"
  case consecutiveStatementsOnSameLine = "consecutive statements on a line must be separated by ';'"
  case cStyleForLoop = "C-style for statement has been removed in Swift 3"
  case defaultCannotBeUsedWithWhere = "'default' cannot be used with a 'where' guard expression"
  case editorPlaceholderInSourceFile = "editor placeholder in source file"
  case expectedExpressionAfterTry = "expected expression after 'try'"
  case missingColonInTernaryExprDiagnostic = "expected ':' after '? ...' in ternary expression"
  case missingFunctionParameterClause = "expected argument list in function declaration"
  case standaloneSemicolonStatement = "standalone ';' statements are not allowed"
  case throwsInReturnPosition = "'throws' may only occur before '->'"
  case tryMustBePlacedOnReturnedExpr = "'try' must be placed on the returned expression"
  case tryMustBePlacedOnThrownExpr = "'try' must be placed on the thrown expression"
  case tryOnInitialValueExpression = "'try' must be placed on the initial value expression"
  case unexpectedSemicolon = "unexpected ';' separator"

  public var message: String { self.rawValue }

  public var diagnosticID: MessageID {
    MessageID(domain: diagnosticDomain, id: "\(type(of: self)).\(self)")
  }

  public var severity: DiagnosticSeverity { .error }
}

// MARK: - Diagnostics (please sort alphabetically)

public struct EffectsSpecifierAfterArrow: ParserError {
  public let effectsSpecifiersAfterArrow: [TokenSyntax]

  public var message: String {
    "\(missingNodesDescription(effectsSpecifiersAfterArrow)) may only occur before '->'"
  }
}

public struct ExtaneousCodeAtTopLevel: ParserError {
  public let extraneousCode: UnexpectedNodesSyntax

  public var message: String {
    if let shortContent = extraneousCode.contentForDiagnosticsIfShortSingleLine {
      return "extraneous '\(shortContent)' at top level"
    } else {
      return "extraneous code at top level"
    }
  }
}

public struct InvalidIdentifierError: ParserError {
  public let invalidIdentifier: TokenSyntax

  public var message: String {
    switch invalidIdentifier.tokenKind {
    case .unknown(let text) where text.first?.isNumber == true:
      return "identifier can only start with a letter or underscore, not a number"
    case .wildcardKeyword:
      return "'\(invalidIdentifier.text)' cannot be used as an identifier here"
    case let tokenKind where tokenKind.isKeyword:
      return "keyword '\(invalidIdentifier.text)' cannot be used as an identifier here"
    default:
      return "'\(invalidIdentifier.text)' is not a valid identifier"
    }
  }
}

public struct MissingAttributeArgument: ParserError {
  /// The name of the attribute that's missing the argument, without `@`.
  public let attributeName: TokenSyntax

  public var message: String {
    return "expected argument for '@\(attributeName)' attribute"
  }
}

public struct TryCannotBeUsed: ParserError {
  public let nextToken: TokenSyntax

  public var message: String {
    return "'try' cannot be used with '\(nextToken.text)'"
  }
}

public struct UnexpectedNodesError: ParserError {
  public let unexpectedNodes: UnexpectedNodesSyntax

  public var message: String {
    var message = "unexpected text"
    if let shortContent = unexpectedNodes.contentForDiagnosticsIfShortSingleLine {
      message += " '\(shortContent)'"
    }
    if let parent = unexpectedNodes.parent {
      if let parentTypeName = parent.nodeTypeNameForDiagnostics(allowBlockNames: false), parent.children(viewMode: .sourceAccurate).first?.id == unexpectedNodes.id {
        message += " before \(parentTypeName)"
      } else if let parentTypeName = parent.ancestorOrSelf(where: { $0.nodeTypeNameForDiagnostics(allowBlockNames: false) != nil })?.nodeTypeNameForDiagnostics(allowBlockNames: false) {
        message += " in \(parentTypeName)"
      }
    }
    return message
  }
}

// MARK: - Fix-Its (please sort alphabetically)

public enum StaticParserFixIt: String, FixItMessage {
  case insertSemicolon = "insert ';'"
  case insertAttributeArguments = "insert attribute argument"
  case wrapKeywordInBackticks = "if this name is unavoidable, use backticks to escape it"

  public var message: String { self.rawValue }

  public var fixItID: MessageID {
    MessageID(domain: diagnosticDomain, id: "\(type(of: self)).\(self)")
  }
}

public struct MoveTokensAfterFixIt: ParserFixIt {
  /// The token that should be moved
  public let movedTokens: [TokenSyntax]

  /// The token after which `movedTokens` should be moved
  public let after: RawTokenKind

  public var message: String {
    "move \(missingNodesDescription(movedTokens)) after '\(after.nameForDiagnostics)'"
  }
}

public struct MoveTokensInFrontOfFixIt: ParserFixIt {
  /// The token that should be moved
  public let movedTokens: [TokenSyntax]

  /// The token after which 'try' should be moved
  public let inFrontOf: RawTokenKind

  public var message: String {
    "move \(missingNodesDescription(movedTokens)) in front of '\(inFrontOf.nameForDiagnostics)'"
  }
}

public struct RemoveRedundantFixIt: ParserFixIt {
  public let removeTokens: [TokenSyntax]

  public var message: String {
    "remove redundant \(missingNodesDescription(removeTokens))"
  }
}

public struct RemoveTokensFixIt: ParserFixIt {
  public let tokensToRemove: [TokenSyntax]

  public var message: String {
    "remove \(missingNodesDescription(tokensToRemove))"
  }
}

public struct ReplaceTokensFixIt: ParserFixIt {
  public let replaceTokens: [TokenSyntax]

  public let replacement: TokenSyntax

  public var message: String {
    "replace \(missingNodesDescription(replaceTokens)) by '\(replacement.text)'"
  }
}
