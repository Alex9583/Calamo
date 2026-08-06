//! Pins are byte-identical to the corpus-validated models: bumping a
//! revision re-baselines the goldens. Folder names are FluidAudio's lookup
//! keys — only the CTC keeps its `-coreml` suffix.

pub struct ModelSpec {
    pub name: &'static str,
    pub repo: &'static str,
    /// A commit hash, never a branch.
    pub revision: &'static str,
    pub folder: &'static str,
    pub files: &'static [FileSpec],
}

pub struct FileSpec {
    /// Repo-relative.
    pub path: &'static str,
    pub size: u64,
    pub sha256: &'static str,
}

impl ModelSpec {
    pub fn local_path(&self, file: &FileSpec) -> String {
        if self.folder.is_empty() {
            file.path.to_string()
        } else {
            format!("{}/{}", self.folder, file.path)
        }
    }
}

/// Locked by the cleanup prototype.
pub const PINNED_GGUF_SHA256: &str =
    "aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223";

pub const GGUF_FILE_NAME: &str = "Qwen3.5-2B-Q4_K_M.gguf";

pub const CATALOG: &[ModelSpec] = &[
    ModelSpec {
        name: "parakeet-tdt-0.6b-v3",
        repo: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
        revision: "aed02740059203c4a87495924f685de3722ae9ce",
        folder: "parakeet-tdt-0.6b-v3",
        files: TDT_FILES,
    },
    ModelSpec {
        name: "parakeet-ctc-110m",
        repo: "FluidInference/parakeet-ctc-110m-coreml",
        revision: "accdafd8cf8a2ff1cabe3c11e54416b405d409aa",
        folder: "parakeet-ctc-110m-coreml",
        files: CTC_FILES,
    },
    ModelSpec {
        name: "qwen3.5-2b-cleanup",
        repo: "unsloth/Qwen3.5-2B-GGUF",
        revision: "f6d5376be1edb4d416d56da11e5397a961aca8ae",
        folder: "",
        files: &[file(GGUF_FILE_NAME, 1_280_835_840, PINNED_GGUF_SHA256)],
    },
];

pub fn tdt() -> &'static ModelSpec {
    &CATALOG[0]
}

pub fn ctc() -> &'static ModelSpec {
    &CATALOG[1]
}

pub fn cleanup() -> &'static ModelSpec {
    &CATALOG[2]
}

const fn file(path: &'static str, size: u64, sha256: &'static str) -> FileSpec {
    FileSpec { path, size, sha256 }
}

const TDT_FILES: &[FileSpec] = &[
    file(
        "config.json",
        2,
        "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    ),
    file(
        "parakeet_v3_vocab.json",
        151_122,
        "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735",
    ),
    file(
        "parakeet_vocab.json",
        151_122,
        "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735",
    ),
    file(
        "Preprocessor.mlmodelc/analytics/coremldata.bin",
        243,
        "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d",
    ),
    file(
        "Preprocessor.mlmodelc/coremldata.bin",
        486,
        "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d",
    ),
    file(
        "Preprocessor.mlmodelc/metadata.json",
        2_841,
        "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf",
    ),
    file(
        "Preprocessor.mlmodelc/model.mil",
        28_181,
        "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93",
    ),
    file(
        "Preprocessor.mlmodelc/weights/weight.bin",
        491_072,
        "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea",
    ),
    file(
        "Encoder.mlmodelc/analytics/coremldata.bin",
        243,
        "42e638870d73f26b332918a3496ce36793fbb413a81cbd3d16ba01328637a105",
    ),
    file(
        "Encoder.mlmodelc/coremldata.bin",
        485,
        "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86",
    ),
    file(
        "Encoder.mlmodelc/metadata.json",
        2_921,
        "da24da9cca943fb29d7fa8e376d57fca7cb3aa08ca51b956b0b0e56813f087e9",
    ),
    file(
        "Encoder.mlmodelc/model.mil",
        959_769,
        "ed7b19156ca29fa7dfd6891deb9fda4b0e8893f68597c985d135736546a43808",
    ),
    file(
        "Encoder.mlmodelc/weights/weight.bin",
        445_187_200,
        "e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421",
    ),
    file(
        "Decoder.mlmodelc/analytics/coremldata.bin",
        243,
        "4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350",
    ),
    file(
        "Decoder.mlmodelc/coremldata.bin",
        554,
        "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99",
    ),
    file(
        "Decoder.mlmodelc/metadata.json",
        3_427,
        "a39e93cd8371b8ded92635c7804fcd0590f0d1dd9415c6d19a0484be073077d9",
    ),
    file(
        "Decoder.mlmodelc/model.mil",
        13_110,
        "ef2a0a281695398a62fde86ac269c68f73d5b578d7ed3b31f2ba91a2d1ea1f35",
    ),
    file(
        "Decoder.mlmodelc/weights/weight.bin",
        23_604_992,
        "48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41",
    ),
    file(
        "JointDecisionv3.mlmodelc/analytics/coremldata.bin",
        243,
        "26def4bf73dd56d29dee21c8ef97cb8969e62f6120ed1adc91e46828e2737b6c",
    ),
    file(
        "JointDecisionv3.mlmodelc/coremldata.bin",
        521,
        "f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342",
    ),
    file(
        "JointDecisionv3.mlmodelc/metadata.json",
        3_453,
        "d9307211b9a37e0f0ac260c7660b1571a3de25841035cfdf9b58fd40425f890f",
    ),
    file(
        "JointDecisionv3.mlmodelc/model.mil",
        11_775,
        "be60732943389a047175111a83f8839f3eb39d4803adafa828a0871b2f39818d",
    ),
    file(
        "JointDecisionv3.mlmodelc/weights/weight.bin",
        12_642_764,
        "4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e",
    ),
];

const CTC_FILES: &[FileSpec] = &[
    file(
        "config.json",
        121,
        "1fd77c83ea89285c242608d95a7992f146867481adc3938be730a064f3a63305",
    ),
    file(
        "ctc_head_metadata.json",
        382,
        "26100793bc6d3642d345cc52d7b8611d11510fa870d4d66ad93b204e0ba29d2e",
    ),
    file(
        "special_tokens_map.json",
        279,
        "af8c98917af6cb493513e5f1f8a35efdc28fa82cac15b2bb5f065d64f8bc904d",
    ),
    file(
        "tokenizer.json",
        360_106,
        "9f7c517c0bf644b1b690ab037bab4d4c53aecd38e047e7154d011013ab9160db",
    ),
    file(
        "tokenizer_config.json",
        632,
        "7a29ed0fec88768d8666d65be8dc00ae41a60c4b7758c4df99a912108e62a23a",
    ),
    file(
        "vocab.json",
        16_086,
        "319d386eead79aadc80df9c3ecc8340d1a727efb7c02a8847eb940380dd61e1f",
    ),
    file(
        "MelSpectrogram.mlmodelc/analytics/coremldata.bin",
        243,
        "22f2a8cba1de25c984050566b534a1d8caf22a82f9fe6c1c6f3149a0dd7e8ae3",
    ),
    file(
        "MelSpectrogram.mlmodelc/coremldata.bin",
        330,
        "3a32ec67c76aa0aa2faef518413c311493e89aeb7fa11289fa4b8653ab8a160c",
    ),
    file(
        "MelSpectrogram.mlmodelc/metadata.json",
        1_962,
        "5e11d21a65c02bcfc37db43e941978e5d60d59e0efeadfda08e41f33b4f835d3",
    ),
    file(
        "MelSpectrogram.mlmodelc/model.mil",
        12_584,
        "0a7cb5693b39667295218bac5c7c09053f6bcd4b32699a83d06ac35d14ac6b79",
    ),
    file(
        "MelSpectrogram.mlmodelc/weights/weight.bin",
        567_712,
        "0a89c055bfde9022029d3cc59a23e949385e063974460d8eaec3a7614c3eaaa8",
    ),
    file(
        "AudioEncoder.mlmodelc/analytics/coremldata.bin",
        243,
        "8906c823e9bb3bf6b16d9f0308f98cd70573526333ad85dd767dc3f9ae6b25fa",
    ),
    file(
        "AudioEncoder.mlmodelc/coremldata.bin",
        505,
        "a88b002b58193b4c31211754cdfdf220a85f9651dc61caf336ab84400cbc191a",
    ),
    file(
        "AudioEncoder.mlmodelc/metadata.json",
        3_456,
        "4f288bfe5cbe867ef1e592cdae33578b2fe59ada69182fc12209879558f985c2",
    ),
    file(
        "AudioEncoder.mlmodelc/model.mil",
        1_060_924,
        "2f84ef93a69115e55f3b5d8ce695b3c937de1833d4d229620634fae967cd587e",
    ),
    file(
        "AudioEncoder.mlmodelc/weights/weight.bin",
        100_778_304,
        "af0734b4a5d7465ad9e8bb170f0c53c5e6b91ebb75a9bdf88d3f59ae4ad6aebd",
    ),
];
