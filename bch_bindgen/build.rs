#[derive(Debug)]
pub struct Fix753 {}
impl bindgen::callbacks::ParseCallbacks for Fix753 {
    fn item_name(&self, original_item_name: &str) -> Option<String> {
        Some(original_item_name.trim_start_matches("Fix753_").to_owned())
    }
}

fn main() {
    use std::path::PathBuf;

    println!("cargo:rerun-if-changed=src/libbcachefs_wrapper.h");

    let out_dir: PathBuf = std::env::var_os("OUT_DIR")
        .expect("ENV Var 'OUT_DIR' Expected")
        .into();
    let top_dir: PathBuf = std::env::var_os("CARGO_MANIFEST_DIR")
        .expect("ENV Var 'CARGO_MANIFEST_DIR' Expected")
        .into();

    let urcu = pkg_config::probe_library("liburcu").expect("Failed to find urcu lib");
    let bindings = bindgen::builder()
        .formatter(bindgen::Formatter::Prettyplease)
        .header(
            top_dir
                .join("src")
                .join("libbcachefs_wrapper.h")
                .display()
                .to_string(),
        )
        .clang_args(
            urcu
                .include_paths
                .iter()
                .map(|p| format!("-I{}", p.display())),
        )
        .clang_arg("-I..")
        .clang_arg("-I../c_src")
        .clang_arg("-I../include")
        .clang_arg("-DZSTD_STATIC_LINKING_ONLY")
        .clang_arg("-DNO_BCACHEFS_FS")
        .clang_arg("-D_GNU_SOURCE")
        .clang_arg("-DRUST_BINDGEN")
        .clang_arg("-fkeep-inline-functions")
        .derive_debug(true)
        .derive_default(true)
        .layout_tests(true)
        .default_enum_style(bindgen::EnumVariation::Rust {
            non_exhaustive: true,
        })
        .allowlist_function("bcachefs_usage")
        .allowlist_function("raid_init")
        .allowlist_function("cmd_.*")
        .allowlist_function(".*_cmds")
        .allowlist_function(".*bch2_.*")
        .allowlist_function("bio_.*")
        .allowlist_function("derive_passphrase")
        .allowlist_function("request_key")
        .allowlist_function("add_key")
        .allowlist_function("keyctl_search")
        .allowlist_function("match_string")
        .allowlist_function("printbuf.*")
        .blocklist_type("rhash_lock_head")
        .blocklist_type("srcu_struct")
        .allowlist_var("BCH_.*")
        .allowlist_var("KEY_SPEC_.*")
        .allowlist_var("Fix753_FMODE_.*")
        .allowlist_var("bch.*")
        .allowlist_var("__bch2.*")
        .allowlist_var("__BTREE_ITER.*")
        .allowlist_var("BTREE_ITER.*")
        .blocklist_item("bch2_bkey_ops")
        .allowlist_type("bch_.*")
        .allowlist_type("fsck_err_opts")
        .rustified_enum("fsck_err_opts")
        .allowlist_type("nonce")
        .no_debug("bch_replicas_padded")
        .newtype_enum("bch_kdf_types")
        .rustified_enum("bch_key_types")
        .opaque_type("gendisk")
        .opaque_type("gc_stripe")
        .opaque_type("open_bucket.*")
        .opaque_type("replicas_delta_list")
        .no_copy("btree_trans")
        .no_copy("printbuf")
        .no_partialeq("bkey")
        .no_partialeq("bpos")
        .generate_inline_functions(true)
        .parse_callbacks(Box::new(Fix753 {}))
        .generate()
        .expect("BindGen Generation Failiure: [libbcachefs_wrapper]");

    std::fs::write(
        out_dir.join("bcachefs.rs"),
        packed_and_align_fix(bindings.to_string()),
    )
    .expect("Writing to output file failed for: `bcachefs.rs`");

    let keyutils = pkg_config::probe_library("libkeyutils").expect("Failed to find keyutils lib");
    let bindings = bindgen::builder()
        .header(
            top_dir
                .join("src")
                .join("keyutils_wrapper.h")
                .display()
                .to_string(),
        )
        .clang_args(
            keyutils
                .include_paths
                .iter()
                .map(|p| format!("-I{}", p.display())),
        )
        .generate()
        .expect("BindGen Generation Failiure: [Keyutils]");
    bindings
        .write_to_file(out_dir.join("keyutils.rs"))
        .expect("Writing to output file failed for: `keyutils.rs`");
}

// rustc has a limitation where it does not allow structs to have both a "packed" and "align"
// attribute. This means that bindgen cannot copy all attributes from some C types, like struct
// bkey, that are both packed and aligned.
//
// bindgen tries to handle this situation smartly and for many types it will only apply a
// "packed(N)" attribute if that is good enough. However, there are a few types where bindgen
// does end up generating both a packed(N) and align(N) attribute. These types can't be compiled
// by rustc.
//
// To work around this, we can remove either the "packed" or "align" attribute. It happens that
// for all the types with this problem in bcachefs, removing the "packed" attribute and keeping
// the "align" attribute results in a type with the correct ABI.
//
// This function applies that transformation to the following bcachefs types that need it:
//   - bkey
//   - bch_extent_crc32
//   - bch_extent_ptr
//   - btree_node
fn packed_and_align_fix(bindings: std::string::String) -> std::string::String {
    bindings
        .replace(
            "#[repr(C, packed(8))]\n#[repr(align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bkey {",
            "#[repr(C, align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bkey {",
        )
        .replace(
            "#[repr(C, packed(8))]\n#[repr(align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bch_extent_crc32 {",
            "#[repr(C, align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bch_extent_crc32 {",
        )
        .replace(
            "#[repr(C, packed(8))]\n#[repr(align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bch_extent_ptr {",
            "#[repr(C, align(8))]\n#[derive(Debug, Default, Copy, Clone)]\npub struct bch_extent_ptr {",
        )
        .replace(
            "#[repr(C, packed(8))]\npub struct btree_node {",
            "#[repr(C, align(8))]\npub struct btree_node {",
        )
}
