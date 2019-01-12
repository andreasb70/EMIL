//
//  main.swift
//  EMIL
//
//  Created by Andi on 12.01.19.
//  Copyright © 2019 Andreas Binner. All rights reserved.
//

import Foundation

func emilFactorial(_ program: EMILProgram, cmd: Command) -> CommandStatus {
    if let arg = program.getArgument(cmd, num: 0) {
        if case let .varFloat(val) = arg {
            var mult = val
            var retVal: Double = 1.0
            while mult > 0.0 {
                retVal *= mult
                mult -= 1.0
            }
            if program.setReturn(cmd, val: .varFloat(retVal)) == false {
                return .failure
            }
            return .success
        }
    }
    return .failure
}

let script = try! String(contentsOfFile: "test.emil")
let runtime = EMILRuntime()
let _ = runtime.registerCommand("f fact f", handler: emilFactorial)

let emil = EMIL(script: script, runtime: runtime)
if let program = emil.compile() {
    runtime.run(program)
}
