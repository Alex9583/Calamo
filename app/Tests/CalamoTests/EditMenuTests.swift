import AppKit
import Testing

@testable import Calamo

@MainActor
struct EditMenuTests {
    @Test func givenTheInstalledMainMenuWhenResolvingCmdVThenPasteIsTheAction() {
        // Given
        let menu = EditMenu.mainMenu()

        // When
        let item = editItems(of: menu).first { $0.keyEquivalent == "v" }

        // Then
        #expect(item?.action == #selector(NSText.paste(_:)))
        #expect(item?.keyEquivalentModifierMask == .command)
    }

    @Test func givenTheInstalledMainMenuWhenListingKeyEquivalentsThenEditingBasicsAreWired() {
        // Given
        let menu = EditMenu.mainMenu()

        // When
        let keys = Set(editItems(of: menu).map(\.keyEquivalent))

        // Then
        #expect(keys.isSuperset(of: ["z", "Z", "x", "c", "v", "a"]))
    }

    private func editItems(of menu: NSMenu) -> [NSMenuItem] {
        menu.items.compactMap(\.submenu).flatMap(\.items)
    }
}
