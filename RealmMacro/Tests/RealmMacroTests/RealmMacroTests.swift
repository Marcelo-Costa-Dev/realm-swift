import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import RealmMacroMacros

final class RealmMacroTests: XCTestCase {
    func testStuff() {
        assertMacroExpansion(
            #"""
            @RealmModel class Foo: Object {
                @Persisted(primaryKey: true) var value1: Int
                @Persisted var value2: Float
                @Persisted(indexed: true) var value3: String
                @Persisted var value4: Decimal128?
            }
            """#,
            expandedSource: #"""
            class Foo: Object {
                @Persisted var value1: Int
                @Persisted var value2: Float
                @Persisted var value3: String
                @Persisted var value4: Decimal128?

                static func schema() -> [RLMProperty] {
                    return [
                        RLMProperty(name: "value1", type: Int.self, keyPath: \Foo.value1),
                        RLMProperty(name: "value2", type: Float.self, keyPath: \Foo.value2),
                        RLMProperty(name: "value3", type: String.self, keyPath: \Foo.value3)
                        RLMProperty(name: "value4", type: Decimal128?.self, keyPath: \Foo.value4)
                    ]
                }
            }
            """#,
            macros: ["RealmModel": RealmObjectMacro.self])
    }
}
