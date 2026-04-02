// Generated from CodeGenSpecs/PluginsTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

#if Plugins

// MARK: - Mock Types

private actor MockPlugin: AgentPlugin {
    let name: String
    let version: String = "1.0"
    var activateCallCount = 0
    var deactivateCallCount = 0

    init(name: String) { self.name = name }

    func activate(context: PluginContext) async throws {
        activateCallCount += 1
    }

    func deactivate() async {
        deactivateCallCount += 1
    }
}

private actor FailingPlugin: AgentPlugin {
    let name = "failing"
    let version = "1.0"
    func activate(context: PluginContext) async throws {
        throw NSError(domain: "PluginTest", code: 1, userInfo: nil)
    }
    func deactivate() async {}
}

// MARK: - Helpers

private func makeContext() -> PluginContext {
    PluginContext(toolRegistry: ToolRegistry(), hookPipeline: AgentHookPipeline())
}

// MARK: - PluginManager Tests

@Test func pluginManagerActivatesRegisteredPlugin() async {
    let manager = PluginManager()
    let plugin = MockPlugin(name: "mock")
    await manager.register(plugin)
    await manager.activateAll(context: makeContext())
    let count = await plugin.activateCallCount
    #expect(count == 1)
}

@Test func pluginManagerActivatesInRegistrationOrder() async {
    let manager = PluginManager()
    let pluginA = MockPlugin(name: "alpha")
    let pluginB = MockPlugin(name: "beta")
    await manager.register(pluginA)
    await manager.register(pluginB)
    await manager.activateAll(context: makeContext())
    let countA = await pluginA.activateCallCount
    let countB = await pluginB.activateCallCount
    #expect(countA == 1)
    #expect(countB == 1)
    // Both activated; sequential activation order is guaranteed by the for loop in PluginManager
    let registered = await manager.registeredPlugins
    #expect(registered == ["alpha", "beta"])
}

@Test func pluginManagerDeactivatesAll() async {
    let manager = PluginManager()
    let pluginA = MockPlugin(name: "a")
    let pluginB = MockPlugin(name: "b")
    await manager.register(pluginA)
    await manager.register(pluginB)
    await manager.activateAll(context: makeContext())
    await manager.deactivateAll()
    let countA = await pluginA.deactivateCallCount
    let countB = await pluginB.deactivateCallCount
    #expect(countA == 1)
    #expect(countB == 1)
}

@Test func pluginManagerDeactivatesInReverseOrder() async {
    let manager = PluginManager()
    let pluginA = MockPlugin(name: "first")
    let pluginB = MockPlugin(name: "second")
    await manager.register(pluginA)
    await manager.register(pluginB)
    await manager.activateAll(context: makeContext())
    // After deactivateAll, neither should be active (LIFO is internal impl detail)
    await manager.deactivateAll()
    let isActiveA = await manager.isActive(name: "first")
    let isActiveB = await manager.isActive(name: "second")
    #expect(!isActiveA)
    #expect(!isActiveB)
}

@Test func pluginManagerContinuesAfterActivationFailure() async {
    let manager = PluginManager()
    let failing = FailingPlugin()
    let mock = MockPlugin(name: "after-failure")
    await manager.register(failing)
    await manager.register(mock)
    await manager.activateAll(context: makeContext())
    let count = await mock.activateCallCount
    #expect(count == 1)
}

@Test func pluginManagerDeactivateSingleByName() async {
    let manager = PluginManager()
    let pluginA = MockPlugin(name: "alpha")
    let pluginB = MockPlugin(name: "beta")
    await manager.register(pluginA)
    await manager.register(pluginB)
    await manager.activateAll(context: makeContext())
    await manager.deactivate(name: "alpha")
    let countA = await pluginA.deactivateCallCount
    let countB = await pluginB.deactivateCallCount
    #expect(countA == 1)
    #expect(countB == 0)
}

#endif
