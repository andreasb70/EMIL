//
//  EMILRuntime.swift
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

final class EMILProgram {
    var commands: [Command] = []
    var variables: [String: Variable] = [:]
    var pc: Int = 0
    var running = false
    
    func reset() {
        pc = 0
        if let main = getVariable("main:") {
            if case .varInteger(let val) = main {
                pc = val
            }
        }
    }
    
    func jump(_ dest: Int) {
        pc = dest
    }
    
    func next() {
        pc += 1
    }
    
    func getCommand() -> Command? {
        if pc == commands.count {
            return nil
        }
        return commands[pc]
    }
    
    func numArguments(_ command: Command) -> Int {
        return command.arguments.count
    }
    
    func getArgument(_ command: Command, num argnum: Int) -> Variable? {
        var num = argnum
        if command.firstArgIsReturn == true {
            num += 1
        }
        if num < 0 || num >= command.arguments.count {
            return nil
        }
        let arg = command.arguments[num]
        switch arg {
        case .literalInteger(let val):
            return Variable.varInteger(val)
        case .literalFloat(let val):
            return Variable.varFloat(val)
        case .literalString(let val):
            return Variable.varString(expandString(val))
        case .literalOperator(let op):
            return Variable.varOperator(op)
        case .argInteger(let name):
            return getVariable(name)
        case .argFloat(let name):
            return getVariable(name)
        case .argString(let name):
            return getVariable(name)
        case .jumpDest(let dest):
            return Variable.varInteger(dest)
        }
    }
    
    func setReturn(_ command: Command, val: Variable) -> Bool {
        let num = 0
        if command.firstArgIsReturn == false {
            return false
        }
        let arg = command.arguments[num]
        switch arg {
        case .argInteger(let name):
            return setVariable(name, val: val)
        case .argFloat(let name):
            return setVariable(name, val: val)
        case .argString(let name):
            return setVariable(name, val: val)
        default:
            return false
        }
    }
    
    func expandString(_ str: String) -> String {
        var newString = ""
        var varName = ""
        var inBrackets = false
        for c in str {
            if c == "[" {
                inBrackets = true
                varName = ""
            } else if c == "]" {
                inBrackets = false
                if let v = getVariable(varName) {
                    newString += v.formatted
                }
            } else if inBrackets {
                varName.append(c)
            } else {
                newString.append(c)
            }
        }
        if let returnStr = newString.removingPercentEncoding {
            return returnStr
        }
        return newString
    }
    
    func getVariable(_ name: String) -> Variable? {
        if let v = variables[name] {
            if case .varString(let str) = v {
                return .varString(expandString(str))
            }
            return v
        }
        return nil
    }
    
    func setVariable(_ name: String, val: Variable) -> Bool {
        if let oldVal = variables[name] {
            if val.signature == oldVal.signature {
                variables[name] = val
                return true
            } else {
                return false
            }
        }
        return false
    }
}

enum CommandStatus {
    case success, didJump, failure, stop
}

typealias CommandExec = (_ program: EMILProgram, _ cmd: Command)->CommandStatus

struct CommandHandler {
    var name: String
    var argTypes: [VariableType]
    var hasReturnValue: Bool
    var signature: String
    var handler: CommandExec
    
    init(name: String, handler: @escaping CommandExec) {
        self.name = name
        self.handler = handler
        self.argTypes = []
        self.hasReturnValue = false
        self.signature = ""
    }
}

protocol EMILRuntimeProtocol {
    var commands: [CommandHandler] { get }
    func codeForCommand(_ name: String, signature: String, firstArgIsReturn: Bool) -> Int?
    func signatureForCommand(_ name: String) -> String
    func handlerForCode(_ code: Int) -> CommandHandler?
}

final class EMILRuntime: EMILRuntimeProtocol {
    var commands: [CommandHandler] = []
    var signatures: [String: String] = [:]
    var index: [String: Int] = [:]
    var callStack: [Int] = []
    
    init() {
        let _ = registerCommand("print s", handler: emilPrint)
        let _ = registerCommand("x set x", handler: emilSet)
        let _ = registerCommand("if xox", handler: emilIf)
        let _ = registerCommand("else", handler: emilElse)
        let _ = registerCommand("endif", handler: emilNoop)
        let _ = registerCommand("while xox", handler: emilWhile)
        let _ = registerCommand("wend", handler: emilWend)
        let _ = registerCommand("repeat", handler: emilRepeat)
        let _ = registerCommand("until xox", handler: emilUntil)
        let _ = registerCommand("i add ii", handler: emilAddInteger)
        let _ = registerCommand("f add ff", handler: emilAddFloat)
        let _ = registerCommand("s add ss", handler: emilAddString)
        let _ = registerCommand("i sub ii", handler: emilSubInteger)
        let _ = registerCommand("f sub ff", handler: emilSubFloat)
        let _ = registerCommand("i mult ii", handler: emilMultInteger)
        let _ = registerCommand("f mult ff", handler: emilMultFloat)
        let _ = registerCommand("i div ii", handler: emilDivInteger)
        let _ = registerCommand("f div ff", handler: emilDivFloat)
        let _ = registerCommand("i strlen s", handler: emilStrlen)
        let _ = registerCommand("i integer x", handler: emilInteger)
        let _ = registerCommand("f float x", handler: emilFloat)
        let _ = registerCommand("stop", handler: emilStop)
        let _ = registerCommand("case xox", handler: emilCase)
        let _ = registerCommand("select", handler: emilNoop)
        let _ = registerCommand("selend", handler: emilNoop)
        let _ = registerCommand("call i", handler: emilCall)
        let _ = registerCommand("return", handler: emilReturn)
        let _ = registerCommand("break", handler: emilBreak)
        let _ = registerCommand("fallthrough", handler: emilNoop)
        let _ = registerCommand("f eval :", handler: emilEval)
    }
    
    func signaturesDoMatch(_ sig1: String, sig2: String) -> Bool {
        var cmdSig = sig1
        if let _ = sig1.range(of: ":") {
            cmdSig = sig1.replacingOccurrences(of: ":", with: "")
            while cmdSig.count < sig2.count {
                cmdSig += "x"
            }
        }
        if cmdSig.count != sig2.count {
            return false
        }
        var sig3 = ""
        for (i, s1) in cmdSig.enumerated() {
            if s1 == "x" {
                sig3 += "x"
            } else {
                sig3.append(sig2[sig2.index(sig2.startIndex, offsetBy: i)])
            }
        }
        return cmdSig == sig3
    }
    
    func codeForCommand(_ name: String, signature: String, firstArgIsReturn: Bool) -> Int? {
        for (i,c) in commands.enumerated() {
            if c.name == name && signaturesDoMatch(c.signature, sig2: signature) && c.hasReturnValue == firstArgIsReturn {
                return i
            }
        }
        return nil
    }
    
    func signatureForCommand(_ name: String) -> String {
        return signatures[name] ?? ""
    }
    
    func handlerForCode(_ code: Int) -> CommandHandler? {
        return commands[code]
    }
    
    func registerCommand(_ commandName: String, handler: @escaping CommandExec) -> Bool {
        var ch: CommandHandler
        let comp = commandName.components(separatedBy: " ")
        var name = ""
        var sig = ""
        var hasReturn = false
        switch comp.count {
        case 0:
            return false
        case 1:
            name = comp[0]
        case 2:
            name = comp[0]
            sig = comp[1]
        case 3:
            hasReturn = true
            name = comp[1]
            sig = comp[0] + comp[2]
        default:
            return false
        }
        ch = CommandHandler(name: name, handler: handler)
        ch.hasReturnValue = hasReturn
        ch.signature = sig
        for c in sig {
            switch c {
            case "i":
                ch.argTypes.append(.integerType)
            case "s":
                ch.argTypes.append(.stringType)
            case "f":
                ch.argTypes.append(.floatType)
            case "x":
                ch.argTypes.append(.anyType)
            default:
                break
            }
        }
        index[commandName] = commands.count
        commands.append(ch)
        signatures[name] = sig
        
        return true
    }
    
    func compare(lhs a1: Variable, operator o: Variable, rhs a2: Variable) -> Bool {
        if a1.signature != a2.signature {
            return false
        }
        guard case .varOperator(let op) = o else {
            return false
        }
        switch a1 {
        case .varInteger(let v1):
            if case .varInteger(let v2) = a2 {
                switch op {
                case .Equal:
                    return v1 == v2
                case .LessThan:
                    return v1 < v2
                case .GreaterThan:
                    return v1 > v2
                case .NotEqual:
                    return v1 != v2
                case .LessOrEqual:
                    return v1 <= v2
                case .GreaterOrEqual:
                    return v1 >= v2
                default:
                    return false
                }
            }
        case .varFloat(let v1):
            if case .varFloat(let v2) = a2 {
                switch op {
                case .Equal:
                    return v1 == v2
                case .LessThan:
                    return v1 < v2
                case .GreaterThan:
                    return v1 > v2
                case .NotEqual:
                    return v1 != v2
                case .LessOrEqual:
                    return v1 <= v2
                case .GreaterOrEqual:
                    return v1 >= v2
                default:
                    return false
                }
            }
        case .varString(let v1):
            if case .varString(let v2) = a2 {
                switch op {
                case .Equal:
                    return v1 == v2
                case .LessThan:
                    return v1 < v2
                case .GreaterThan:
                    return v1 > v2
                case .NotEqual:
                    return v1 != v2
                case .LessOrEqual:
                    return v1 <= v2
                case .GreaterOrEqual:
                    return v1 >= v2
                default:
                    return false
                }
            }
        default:
            return false
        }
        return false
    }
    
    func run(_ program: EMILProgram) {
        program.reset()
        while let cmd = program.getCommand() {
            var status: CommandStatus = .failure
            if let handler = handlerForCode(cmd.command) {
                status = handler.handler(program, cmd)
            } else {
                print("Runtime Error")
                return
            }
            if status == .stop {
                break
            }
            if status != .didJump {
                program.next()
            }
        }
    }
    
    func emilCall(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let str = program.getArgument(cmd, num: 0) {
            if case .varInteger(let val) = str {
                callStack.append(program.pc + 1)
                program.jump(val)
                return .didJump
            }
        }
        return .failure
    }
    
    func emilReturn(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if callStack.count > 0 {
            let dest = callStack.removeLast()
            program.jump(dest)
            return .didJump
        }
        return .failure
    }
    
    
    func emilPrint(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let str = program.getArgument(cmd, num: 0) {
            if case .varString(let val) = str {
                print(val)
                return .success
            }
        }
        return .failure
    }
    
    func emilSet(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let src = program.getArgument(cmd, num: 0) {
            if program.setReturn(cmd, val: src) == false {
                return .failure
            }
            return .success
        }
        return .failure
    }
    
    func emilIf(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let op = program.getArgument(cmd, num: 1), let a2 = program.getArgument(cmd, num: 2), let j = program.getArgument(cmd, num: 3) {
            if compare(lhs: a1, operator: op, rhs: a2) == false {
                if case .varInteger(let dest) = j {
                    program.jump(dest)
                    return .didJump
                }
            }
        }
        return .failure
    }
    
    func emilCase(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let op = program.getArgument(cmd, num: 1), let a2 = program.getArgument(cmd, num: 2), let j = program.getArgument(cmd, num: 3) {
            if compare(lhs: a1, operator: op, rhs: a2) == false {
                if case .varInteger(let dest) = j {
                    program.jump(dest)
                    return .didJump
                }
            }
        }
        return .failure
    }
    
    func emilElse(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let j = program.getArgument(cmd, num: 0) {
            if case .varInteger(let dest) = j {
                program.jump(dest)
                return .didJump
            }
        }
        return .failure
    }
    
    func emilBreak(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let j = program.getArgument(cmd, num: 0) {
            if case .varInteger(let dest) = j {
                program.jump(dest)
                return .didJump
            }
        }
        return .failure
    }
    
    func emilNoop(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        return .success
    }
    
    func emilStop(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        return .stop
    }
    
    func emilWhile(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let op = program.getArgument(cmd, num: 1), let a2 = program.getArgument(cmd, num: 2), let j = program.getArgument(cmd, num: 3) {
            if compare(lhs: a1, operator: op, rhs: a2) == false {
                if case .varInteger(let dest) = j {
                    program.jump(dest)
                    return .didJump
                }
            }
        }
        return .failure
    }
    
    func emilWend(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let j = program.getArgument(cmd, num: 0) {
            if case .varInteger(let dest) = j {
                program.jump(dest)
                return .didJump
            }
        }
        return .failure
    }
    
    func emilUntil(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let op = program.getArgument(cmd, num: 1), let a2 = program.getArgument(cmd, num: 2), let j = program.getArgument(cmd, num: 3) {
            if compare(lhs: a1, operator: op, rhs: a2) == false {
                if case .varInteger(let dest) = j {
                    program.jump(dest)
                    return .didJump
                }
            }
        }
        return .failure
    }
    
    func emilRepeat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        return .success
    }
    
    func emilAddInteger(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varInteger(val1) = a1, case let .varInteger(val2) = a2 {
                if program.setReturn(cmd, val: .varInteger(val1 + val2)) == false {
                    return .failure
                }
                return .success
            }
        }
        return .failure
    }
    
    func emilAddFloat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varFloat(val1) = a1, case let .varFloat(val2) = a2 {
                if program.setReturn(cmd, val: .varFloat(val1 + val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilAddString(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varString(val1) = a1, case let .varString(val2) = a2 {
                if program.setReturn(cmd, val: .varString(val1 + val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilSubInteger(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varInteger(val1) = a1, case let .varInteger(val2) = a2 {
                if program.setReturn(cmd, val: .varInteger(val1 - val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilSubFloat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varFloat(val1) = a1, case let .varFloat(val2) = a2 {
                if program.setReturn(cmd, val: .varFloat(val1 - val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilMultInteger(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varInteger(val1) = a1, case let .varInteger(val2) = a2 {
                if program.setReturn(cmd, val: .varInteger(val1 * val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilMultFloat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varFloat(val1) = a1, case let .varFloat(val2) = a2 {
                if program.setReturn(cmd, val: .varFloat(val1 * val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilDivInteger(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varInteger(val1) = a1, case let .varInteger(val2) = a2 {
                if program.setReturn(cmd, val: .varInteger(val1 / val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilDivFloat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let a1 = program.getArgument(cmd, num: 0), let a2 = program.getArgument(cmd, num: 1) {
            if case let .varFloat(val1) = a1, case let .varFloat(val2) = a2 {
                if program.setReturn(cmd, val: .varFloat(val1 / val2)) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilStrlen(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let str = program.getArgument(cmd, num: 0) {
            if case .varString(let val) = str {
                if program.setReturn(cmd, val: .varInteger(val.lengthOfBytes(using: String.Encoding.utf8))) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilInteger(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let arg1 = program.getArgument(cmd, num: 0) {
            if case .varString(let val) = arg1 {
                if let i = Int(val) {
                    if program.setReturn(cmd, val: .varInteger(i)) == false {
                        return .failure
                    }
                    
                    return .success
                }
            }
            if case .varFloat(let val) = arg1 {
                if program.setReturn(cmd, val: .varInteger(Int(val))) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilFloat(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        if let arg1 = program.getArgument(cmd, num: 0) {
            if case .varString(let val) = arg1 {
                if let f = Double(val) {
                    if program.setReturn(cmd, val: .varFloat(f)) == false {
                        return .failure
                    }
                    
                    return .success
                }
            }
            if case .varInteger(let val) = arg1 {
                if program.setReturn(cmd, val: .varFloat(Double(val))) == false {
                    return .failure
                }
                
                return .success
            }
        }
        return .failure
    }
    
    func emilEval(_ program: EMILProgram, cmd: Command) -> CommandStatus {
        let n = program.numArguments(cmd)
        var expr = ""
        for i in 1..<n {
            if let arg = program.getArgument(cmd, num: i-1) {
                switch arg {
                case let .varFloat(val):
                    expr += "\(val)"
                case let .varInteger(val):
                    expr += "\(Double(val))"
                case let .varOperator(val):
                    expr += val.rawValue
                default:
                    return .failure
                }
                //                expr += String(describing: arg)
            }
        }
        let expression = NSExpression(format: expr)
        if let result = expression.expressionValue(with:nil, context: nil) as? Double {
            if program.setReturn(cmd, val: .varFloat(result)) == false {
                return .failure
            }
        } else {
            return .failure
        }
        return .success
    }
}
