import AppKit

/// AppKit resolves Cmd shortcuts through the main menu even for an
/// LSUIElement app that never shows one: without this invisible Edit menu,
/// Cmd-V — typed or the insertion cascade's synthetic one — dies unhandled
/// in Calamo's own windows (wizard trial field, settings).
@MainActor
enum EditMenu {
    static func install(into app: NSApplication) {
        app.mainMenu = mainMenu()
    }

    static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let holder = NSMenuItem()
        holder.submenu = editMenu()
        main.addItem(holder)
        return main
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }
}
