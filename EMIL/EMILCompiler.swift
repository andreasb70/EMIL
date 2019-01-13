//
//  EMILCompiler.swift
//  EMIL
//
//  Licensed under MIT License
//
//  https://github.com/andreasb70/EMIL
//

//  Created by Andi on 12.01.19.
//  Copyright © 2019 Andreas Binner. All rights reserved.
//

import Foundation

enum CompileError {
    case noError, unknownCommand, nestingIf, nestingWhile, nestingRepeat, nestingSelect, nestingCase, unknownVariable, alreadyDeclared
}

enum Operator: String {
    case Assign = ":="
    case Equal = "=="
    case NotEqual = "!="
    case LessOrEqual = "<="
    case GreaterOrEqual = ">="
    case LessThan = "<"
    case GreaterThan = ">"
    // Rest are no real operators, but necessary to support the "eval" command
    case Plus = "+"
    case Minus = "-"
    case Times = "*"
    case Divide = "/"
    case OpenBracket = "("
    case CloseBracket = ")"
    
    static let allValues = [Assign, Equal, NotEqual, LessOrEqual, GreaterOrEqual, LessThan, GreaterThan, Plus, Minus, Times, Divide, OpenBracket, CloseBracket]
    
    static func fromString(_ str: String) -> Operator? {
        for o in allValues {
            if str == o.rawValue {
                return o
            }
        }
        return nil
    }
}

enum VariableType {
    case integerType
    case floatType
    case stringType
    case anyType
    case other
    
    mutating func fromName(_ name: String) {
        if name == "int" {
            self = .integerType
        } else if name == "float" {
            self = .floatType
        } else if name.hasPrefix("str") {
            self = .stringType
        }
    }
    
    init() {
        self = .anyType
    }
}

enum Argument {
    case literalInteger(Int)
    case literalFloat(Double)
    case literalOperator(Operator)
    case literalString(String)
    case argInteger(String)
    case argFloat(String)
    case argString(String)
    case jumpDest(Int)
}

enum Variable {
    case varInteger(Int)
    case varFloat(Double)
    case varString(String)
    case varOperator(Operator)
    
    var signature: String {
        switch self {
        case .varInteger(_):
            return "i"
        case .varFloat(_):
            return "f"
        case .varString(_):
            return "s"
        case .varOperator(_):
            return "o"
        }
    }
    
    var formatted: String {
        switch self {
        case .varInteger(let val):
            return "\(val)"
        case .varFloat(let val):
            return "\(val)"
        case .varString(let val):
            return val
        case .varOperator(let val):
            return val.rawValue
        }
    }
}

struct Command {
    var command: Int
    var arguments: [Argument]
    var firstArgIsReturn: Bool
}

func isMathOperator(_ c: Character, ignoreMinus: Bool) -> Bool {
    if c=="+" || c=="*" || c=="/" || c=="(" || c==")" {
        return true
    }
    if c=="-" && ignoreMinus == false {
        return true
    }
    return false
}

func isOperatorCharacter(_ c: Character) -> Bool {
    if c==":" || c=="=" || c=="!" || c=="<" || c==">" {
        return true
    }
    return false
}

func isDigit(_ c: Character) -> Bool {
    if (c>="0" && c<="9") {
        return true
    }
    return false
}


final class EMIL {
    var script: String
    var runtime: EMILRuntimeProtocol
    var isCompiled = false
    var result: CompileError = .noError
    var program: EMILProgram
    var ifStack: [Int] = []
    var whileStack: [Int] = []
    var repeatStack: [Int] = []
    var caseStack: [Int] = []
    var selectStack: [[Int]] = []
    
    init(script: String, runtime: EMILRuntimeProtocol) {
        self.script = script
        self.runtime = runtime
        self.isCompiled = false
        self.program = EMILProgram()
    }
    
    func guessArgumentType(_ arg: String) -> VariableType {
        if let c = arg.first {
            if (c>="0" && c<="9") || c == "-" {
                if arg.contains(".") {
                    return .floatType
                }
                return .integerType
            } else if c=="\"" {
                return .stringType
            }
        }
        return .other
    }
    
    func parseLine(_ line: String) -> Array<Range<String.Index>> {
        enum State {
            case inSpace, inOperator, inQuote, inMath, other, unknown
        }
        var currentStart = line.startIndex
        var state: State = .other
        var componentRanges: Array<Range<String.Index>> = []
        var lastState: State = .other
        
        // *-12  -> '*' '12' ignoreMinus = true
        // ==-12 -> '==' '-12' ignoreMinus = true
        // a-12  -> 'a' '-' '12' ignoreMinus = false
        // "a"-12 -> '"a"' '-' '12' ignoreMinus = false
        
        for i in line.indices {
            let c = line[i]
            switch state {
            case .other:
                if c == " " {
                    lastState = state
                    state = .inSpace
                    componentRanges.append(currentStart..<i)
                    currentStart = i
                }
                if c == "\"" {
                    lastState = state
                    state = .inQuote
                    componentRanges.append(currentStart..<i)
                    currentStart = i
                }
                if isOperatorCharacter(c) {
                    lastState = state
                    state = .inOperator
                    componentRanges.append(currentStart..<i)
                    currentStart = i
                }
                if isMathOperator(c, ignoreMinus: false) {
                    lastState = state
                    state = .inMath
                    componentRanges.append(currentStart..<i)
                    currentStart = i
                }
            case .inSpace:
                if c != " " {
                    if isOperatorCharacter(c) {
                        state = .inOperator
                    } else if isMathOperator(c, ignoreMinus: (lastState == .inMath || lastState == .inOperator)) {
                        state = .inMath
                    } else if c == "\"" {
                        state = .inQuote
                    } else {
                        state = .other
                    }
                    currentStart = i
                }
            case .inQuote:
                if c == "\"" {
                    lastState = state
                    state = .other
                    let next = line.index(after: i)
                    componentRanges.append(currentStart..<next)
                    currentStart = next
                }
            case .inMath:
                lastState = state
                componentRanges.append(currentStart..<i)
                currentStart = i
                if c == " " {
                    state = .inSpace
                } else if c == "\"" {
                    state = .inQuote
                } else {
                    state = .other
                }
                
            case .inOperator:
                if isOperatorCharacter(c) == false {
                    lastState = state
                    if c == " " {
                        state = .inSpace
                    } else if c == "\"" {
                        state = .inQuote
                    } else {
                        state = .other
                    }
                    componentRanges.append(currentStart..<i)
                    currentStart = i
                }
            default:
                break
            }
        }
        let finalRange = currentStart..<line.endIndex
        if finalRange.isEmpty == false {
            componentRanges.append(finalRange)
        }
        return componentRanges
    }
    
    func compile() -> EMILProgram? {
        let lines = script.components(separatedBy: "\n")
        for (n, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: CharacterSet(charactersIn: " "))
            
            let ranges = parseLine(trimmedLine)
            var components: [String] = []
            for r in ranges {
                let comp = String(trimmedLine[r])
                components.append(comp)
            }
            var lineHandled = false
            if components.count > 0 {
                if components.count > 1 {
                    if components[0] == "VAR" {
                        var type = VariableType()
                        type.fromName(components[1])
                        if createVariables(type, names: components[2].components(separatedBy: ",")) == false {
                            result = .alreadyDeclared
                        }
                        lineHandled = true
                    } else if components[0] == "SUB" {
                        program.variables[components[1]] = .varInteger(program.commands.count)
                        lineHandled = true
                    }
                } else {
                    if components[0] == "MAIN" {
                        program.variables["main:"] = .varInteger(program.commands.count)
                        lineHandled = true
                    }
                }
                
                if lineHandled == false {
                    var didSwap = false
                    if components.count > 1 && components[1] == ":=" {
                        didSwap = true
                        if components.count >= 3 {
                            if guessArgumentType(components[2]) != .other {
                                let temp = components[0]
                                components[0] = "set"
                                components[1] = temp
                            } else {
                                let temp = components[0]
                                components[0] = components[2]
                                components[1] = temp
                                for i in 2..<components.count-1 {
                                    components[i] = components[i+1]
                                }
                                components.removeLast()
                            }
                        }
                    }
                    let (res, cmd) = createCommand(components, isAssignment: didSwap)
                    if var command = cmd {
                        let name = components[0]
                        switch name {
                        case "if":
                            ifStack.append(program.commands.count)
                        case "else":
                            if ifStack.count > 0 {
                                let lastIf = ifStack.removeLast()
                                var ifCmd = program.commands[lastIf]
                                ifCmd.arguments.append(.jumpDest(program.commands.count+1))
                                program.commands[lastIf] = ifCmd
                                ifStack.append(program.commands.count)
                            } else {
                                result = .nestingIf
                            }
                        case "endif":
                            if ifStack.count > 0 {
                                let lastIf = ifStack.removeLast()
                                var ifCmd = program.commands[lastIf]
                                ifCmd.arguments.append(.jumpDest(program.commands.count+1))
                                program.commands[lastIf] = ifCmd
                            } else {
                                result = .nestingIf
                            }
                        case "while":
                            whileStack.append(program.commands.count)
                        case "wend":
                            if whileStack.count > 0 {
                                let lastWhile = whileStack.removeLast()
                                var whileCmd = program.commands[lastWhile]
                                command.arguments.append(.jumpDest(lastWhile))
                                whileCmd.arguments.append(.jumpDest(program.commands.count+1))
                                program.commands[lastWhile] = whileCmd
                            } else {
                                result = .nestingWhile
                            }
                        case "repeat":
                            repeatStack.append(program.commands.count)
                        case "until":
                            if repeatStack.count > 0 {
                                let lastRepeat = repeatStack.removeLast()
                                command.arguments.append(.jumpDest(lastRepeat))
                            } else {
                                result = .nestingRepeat
                            }
                        case "case":
                            caseStack.append(program.commands.count)
                        case "select":
                            selectStack.append([])
                        case "fallthrough":
                            if caseStack.count > 0 {
                                let lastCase = caseStack.removeLast()
                                var caseCmd = program.commands[lastCase]
                                caseCmd.arguments.append(.jumpDest(program.commands.count+1))
                                program.commands[lastCase] = caseCmd
                            } else {
                                result = .nestingCase
                            }
                        case "break":
                            if caseStack.count > 0 {
                                let lastCase = caseStack.removeLast()
                                var caseCmd = program.commands[lastCase]
                                caseCmd.arguments.append(.jumpDest(program.commands.count+1))
                                program.commands[lastCase] = caseCmd
                                if selectStack.count > 0 {
                                    var breakList = selectStack.removeLast()
                                    breakList.append(program.commands.count)
                                    selectStack.append(breakList)
                                } else {
                                    selectStack.append([program.commands.count])
                                }
                            } else {
                                result = .nestingCase
                            }
                        case "selend":
                            if selectStack.count > 0 {
                                let breakList = selectStack.removeLast()
                                for br in breakList {
                                    var breakCmd = program.commands[br]
                                    breakCmd.arguments.append(.jumpDest(program.commands.count+1))
                                    program.commands[br] = breakCmd
                                }
                            } else {
                                result = .nestingSelect
                            }
                        default:
                            break
                        }
                        
                        program.commands.append(command)
                    } else {
                        result = res
                    }
                    
                    
                }
            }
            if result != .noError {
                switch result {
                case .unknownCommand:
                    print("Syntax error for command in line \(n+1): \(line)")
                case .unknownVariable:
                    print("Unknown variable in line \(n+1): \(line)")
                case .nestingIf:
                    print("Missing 'if,else' in line \(n+1): \(line)")
                case .nestingWhile:
                    print("Missing 'while' in line \(n+1): \(line)")
                case .nestingRepeat:
                    print("Missing 'repeat' in line \(n+1): \(line)")
                case .nestingSelect:
                    print("Missing 'select' in line \(n+1): \(line)")
                case .nestingCase:
                    print("Missing 'case' in line \(n+1): \(line)")
                case .alreadyDeclared:
                    print("Variable already declared in line \(n+1): \(line)")
                default:
                    print("Compile error in line \(n+1): \(line)")
                }
                return nil
            }
        }
        if ifStack.count > 0 {
            print("Missing 'endif'")
            return nil
        }
        if whileStack.count > 0 {
            print("Missing 'wend'")
            return nil
        }
        if repeatStack.count > 0 {
            print("Missing 'until'")
            return nil
        }
        if caseStack.count > 0 {
            print("Missing 'break'")
            return nil
        }
        if selectStack.count > 0 {
            print("Missing 'selend'")
            return nil
        }
        return program
    }
    
    func createCommand(_ components: [String], isAssignment: Bool) -> (result: CompileError, command: Command?) {
        var args: [Argument] = []
        let name = components[0]
        for i in 1..<components.count {
            let word = components[i]
            let c = word.first!
            
            var argIdentified = false
            if c == "\"" {
                let r = word.index(after: word.startIndex)..<word.index(before: word.endIndex)
                let a = String(word[r])
                args.append(.literalString(a))
                argIdentified = true
            } else if (c>="0" && c<="9") || (c == "-" && word.count > 1){
                if word.contains(".") {
                    if let val = Double(word) {
                        args.append(.literalFloat(val))
                        argIdentified = true
                    }
                } else {
                    if let val = Int(word) {
                        args.append(.literalInteger(val))
                        argIdentified = true
                    }
                }
            } else if isOperatorCharacter(c) || isMathOperator(c, ignoreMinus: false) {
                if let op = Operator.fromString(word) {
                    args.append(.literalOperator(op))
                    argIdentified = true
                }
            }
            
            if argIdentified == false {
                if let v = program.variables[word] {
                    switch v {
                    case .varFloat:
                        args.append(.argFloat(word))
                    case .varInteger:
                        args.append(.argInteger(word))
                    case .varString:
                        args.append(.argString(word))
                    default:
                        break
                    }
                } else {
                    return (result: .unknownVariable, command: nil)
                }
            }
        }
        var sig = ""
        for (_, arg) in args.enumerated() {
            var sigC = ""
            switch arg {
            case .argFloat:
                sigC = "f"
            case .argInteger:
                sigC = "i"
            case .argString:
                sigC = "s"
            case .literalFloat:
                sigC = "f"
            case .literalInteger:
                sigC = "i"
            case .literalString:
                sigC = "s"
            case .literalOperator:
                sigC = "o"
            default:
                break
            }
            sig += sigC
        }
        if let code = runtime.codeForCommand(name, signature: sig, firstArgIsReturn: isAssignment) {
            return (result: .noError, command: Command(command: code, arguments: args, firstArgIsReturn: isAssignment))
        }
        return (result: .unknownCommand, command: nil)
    }
    
    func createVariables(_ type: VariableType, names: [String]) -> Bool {
        for n in names {
            if let _ = program.variables[n] {
                return false // Variable already declared!
            }
            switch type {
            case .integerType:
                program.variables[n] = .varInteger(0)
            case .stringType:
                program.variables[n] = .varString("")
            case .floatType:
                program.variables[n] = .varFloat(0.0)
            default:
                break
            }
        }
        return true
    }
    
}
