# Icon coordinates sit in the empty band of the background art
# (render-dmg-background.swift): keep the two in sync.
import os.path

app = defines.get("app", "build/Calamo.app")  # noqa: F821

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/Calamo.icns")
background = defines.get("background", "build/dmg-background.tiff")  # noqa: F821
window_rect = ((200, 140), (660, 420))
icon_size = 96
text_size = 12
icon_locations = {"Calamo.app": (165, 180), "Applications": (495, 180)}
default_view = "icon-view"
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
