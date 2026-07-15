// FFI smoke test: calling the stub facade from Swift exercises the whole
// chain — staticlib, generated bindings, modulemap, XCFramework, linker
// settings.
import CalamoCore
import Testing

@Test func stubFacadeReturnsItsMarkerAcrossTheFfi() {
    let marker = DictationEngine().buildChainMarker()
    #expect(marker.contains("calamo-core"))
    #expect(marker.contains("calamo-adapters"))
    #expect(marker.contains("calamo-ffi"))
}
