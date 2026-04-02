import Foundation
import Testing
@testable import UrkelAST

@Suite("UrkelAST — StateDecl")
struct StateDeclTests {

    // MARK: StateKind

    @Test("StateKind raw values are correct")
    func stateKindRawValues() {
        #expect(StateKind.`init`.rawValue == "init")
        #expect(StateKind.state.rawValue  == "state")
        #expect(StateKind.final.rawValue  == "final")
    }

    @Test("StateKind equality")
    func stateKindEquality() {
        #expect(StateKind.`init` == .`init`)
        #expect(StateKind.state  == .state)
        #expect(StateKind.final  == .final)
        #expect(StateKind.`init` != .state)
    }

    // MARK: HistoryModifier

    @Test("HistoryModifier cases are distinct")
    func historyModifierCases() {
        #expect(HistoryModifier.shallow != .deep)
        #expect(HistoryModifier.shallow == .shallow)
        #expect(HistoryModifier.deep    == .deep)
    }

    // MARK: SimpleStateDecl

    @Test("SimpleStateDecl default params and history are empty/nil")
    func simpleStateDeclDefaults() {
        let s = SimpleStateDecl(kind: .state, name: "Running")
        #expect(s.kind == .state)
        #expect(s.name == "Running")
        #expect(s.params.isEmpty)
        #expect(s.history == nil)
        #expect(s.docComments.isEmpty)
    }

    @Test("SimpleStateDecl stores all fields")
    func simpleStateDeclStoresFields() {
        let param = Parameter(label: "data", typeExpr: "String")
        let doc   = DocComment(text: "A running state")
        let s = SimpleStateDecl(
            kind: .state,
            params: [param],
            name: "Running",
            history: .shallow,
            docComments: [doc]
        )
        #expect(s.params.count == 1)
        #expect(s.params[0].label == "data")
        #expect(s.history == .shallow)
        #expect(s.docComments.count == 1)
        #expect(s.docComments[0].text == "A running state")
    }

    @Test("SimpleStateDecl equality")
    func simpleStateDeclEquality() {
        let s1 = SimpleStateDecl(kind: .`init`, name: "Idle")
        let s2 = SimpleStateDecl(kind: .`init`, name: "Idle")
        let s3 = SimpleStateDecl(kind: .state, name: "Idle")
        #expect(s1 == s2)
        #expect(s1 != s3)
    }

    // MARK: CompoundStateDecl

    @Test("CompoundStateDecl default fields")
    func compoundStateDeclDefaults() {
        let c = CompoundStateDecl(name: "Active")
        #expect(c.name == "Active")
        #expect(c.history == nil)
        #expect(c.children.isEmpty)
        #expect(c.innerTransitions.isEmpty)
        #expect(c.docComments.isEmpty)
    }

    @Test("CompoundStateDecl stores children and history")
    func compoundStateDeclStoresChildren() {
        let child1 = SimpleStateDecl(kind: .`init`, name: "Playing")
        let child2 = SimpleStateDecl(kind: .state, name: "Paused")
        let c = CompoundStateDecl(
            name: "Media",
            history: .deep,
            children: [child1, child2]
        )
        #expect(c.history == .deep)
        #expect(c.children.count == 2)
        #expect(c.children[0].name == "Playing")
        #expect(c.children[1].name == "Paused")
    }

    @Test("CompoundStateDecl equality")
    func compoundStateDeclEquality() {
        let c1 = CompoundStateDecl(name: "Active", children: [SimpleStateDecl(kind: .`init`, name: "Playing")])
        let c2 = CompoundStateDecl(name: "Active", children: [SimpleStateDecl(kind: .`init`, name: "Playing")])
        let c3 = CompoundStateDecl(name: "Active", children: [SimpleStateDecl(kind: .state, name: "Paused")])
        #expect(c1 == c2)
        #expect(c1 != c3)
    }

    // MARK: StateDecl enum

    @Test("StateDecl.name returns simple state name")
    func stateDeclNameSimple() {
        let decl = StateDecl.simple(SimpleStateDecl(kind: .`init`, name: "Idle"))
        #expect(decl.name == "Idle")
    }

    @Test("StateDecl.name returns compound state name")
    func stateDeclNameCompound() {
        let decl = StateDecl.compound(CompoundStateDecl(name: "Active"))
        #expect(decl.name == "Active")
    }

    @Test("StateDecl.docComments returns simple state doc comments")
    func stateDeclDocCommentsSimple() {
        let doc  = DocComment(text: "The idle state")
        let decl = StateDecl.simple(SimpleStateDecl(kind: .`init`, name: "Idle", docComments: [doc]))
        #expect(decl.docComments.count == 1)
        #expect(decl.docComments[0].text == "The idle state")
    }

    @Test("StateDecl.docComments returns compound state doc comments")
    func stateDeclDocCommentsCompound() {
        let doc  = DocComment(text: "Active compound state")
        let decl = StateDecl.compound(CompoundStateDecl(name: "Active", docComments: [doc]))
        #expect(decl.docComments.count == 1)
        #expect(decl.docComments[0].text == "Active compound state")
    }

    @Test("StateDecl equality for simple case")
    func stateDeclEqualitySimple() {
        let d1 = StateDecl.simple(SimpleStateDecl(kind: .`init`, name: "Idle"))
        let d2 = StateDecl.simple(SimpleStateDecl(kind: .`init`, name: "Idle"))
        let d3 = StateDecl.simple(SimpleStateDecl(kind: .state, name: "Idle"))
        #expect(d1 == d2)
        #expect(d1 != d3)
    }

    @Test("StateDecl simple != compound even if same name")
    func stateDeclSimpleNotEqualCompound() {
        let d1 = StateDecl.simple(SimpleStateDecl(kind: .state, name: "Active"))
        let d2 = StateDecl.compound(CompoundStateDecl(name: "Active"))
        #expect(d1 != d2)
    }

    // MARK: Codable round-trips

    @Test("SimpleStateDecl Codable round-trip")
    func simpleStateDeclCodable() throws {
        let s = SimpleStateDecl(kind: .state, name: "Running", history: .shallow)
        let data    = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(SimpleStateDecl.self, from: data)
        #expect(decoded == s)
    }

    @Test("CompoundStateDecl Codable round-trip")
    func compoundStateDeclCodable() throws {
        let c = CompoundStateDecl(
            name: "Active",
            history: .deep,
            children: [SimpleStateDecl(kind: .`init`, name: "Playing")]
        )
        let data    = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(CompoundStateDecl.self, from: data)
        #expect(decoded == c)
    }

    @Test("StateDecl enum Codable round-trip — simple case")
    func stateDeclCodableSimple() throws {
        let d    = StateDecl.simple(SimpleStateDecl(kind: .final, name: "Done"))
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(StateDecl.self, from: data)
        #expect(decoded == d)
    }

    @Test("StateDecl enum Codable round-trip — compound case")
    func stateDeclCodableCompound() throws {
        let d = StateDecl.compound(CompoundStateDecl(
            name: "Media",
            children: [SimpleStateDecl(kind: .`init`, name: "Playing")]
        ))
        let data    = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(StateDecl.self, from: data)
        #expect(decoded == d)
    }
}
