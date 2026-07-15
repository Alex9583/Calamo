// Generates the Swift bindings, headers and modulemap from the built
// staticlib (library mode). Invoked by build.sh.
fn main() {
    uniffi::uniffi_bindgen_swift()
}
