{
  description = "Galois Counter Mode (GCM) block cipher mode for AES";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    aes.url = "github:mherlev/aes";
  };

  outputs = { self, nixpkgs, aes }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.iverilog pkgs.verilator pkgs.gcc ];
          };
        });

      packages = forAllSystems (system:
        let
          pkgs    = nixpkgs.legacyPackages.${system};
          aesRtl  = "${aes}/src/rtl";
          gcmRtl  = "src/rtl";
          gcmTb   = "src/tb";

          aesSrcs = "${aesRtl}/aes_core.v ${aesRtl}/aes_decipher_block.v ${aesRtl}/aes_encipher_block.v ${aesRtl}/aes_inv_sbox.v ${aesRtl}/aes_key_mem.v ${aesRtl}/aes_sbox.v";

          mkSim = name: srcs: pkgs.stdenv.mkDerivation {
            pname   = name;
            version = "0.1";
            src     = self;
            nativeBuildInputs = [ pkgs.iverilog ];
            buildPhase   = "iverilog -Wall -o ${name} ${srcs}";
            installPhase = ''
              mkdir -p $out/bin
              cp ${name} $out/bin/${name}
            '';
          };
        in
        {
          ghash   = mkSim "ghash.sim" "${gcmTb}/tb_gcm_ghash.v ${gcmRtl}/gcm.v ${gcmRtl}/gcm_core.v ${gcmRtl}/gcm_ghash.v ${aesSrcs}";
          core    = mkSim "core.sim"  "${gcmTb}/tb_gcm_core.v ${gcmRtl}/gcm.v ${gcmRtl}/gcm_core.v ${gcmRtl}/gcm_ghash.v ${aesSrcs}";
          top     = mkSim "top.sim"   "${gcmTb}/tb_gcm.v ${gcmRtl}/gcm.v ${gcmRtl}/gcm_core.v ${gcmRtl}/gcm_ghash.v ${aesSrcs}";
          default = mkSim "top.sim"   "${gcmTb}/tb_gcm.v ${gcmRtl}/gcm.v ${gcmRtl}/gcm_core.v ${gcmRtl}/gcm_ghash.v ${aesSrcs}";
        });

      checks = forAllSystems (system:
        let
          pkgs    = nixpkgs.legacyPackages.${system};
          pkgs'   = self.packages.${system};
          aesRtl  = "${aes}/src/rtl";
          gcmRtl  = "src/rtl";

          aesSrcs = "${aesRtl}/aes_core.v ${aesRtl}/aes_decipher_block.v ${aesRtl}/aes_encipher_block.v ${aesRtl}/aes_inv_sbox.v ${aesRtl}/aes_key_mem.v ${aesRtl}/aes_sbox.v";

          mkSimCheck = name: pkg: pkgs.runCommand "sim-${name}" {} ''
            ${pkg}/bin/${name}.sim | tee /dev/stderr
            touch $out
          '';
        in
        {
          lint = pkgs.stdenv.mkDerivation {
            name = "gcm-lint";
            src  = self;
            nativeBuildInputs = [ pkgs.verilator ];
            buildPhase = ''
              verilator +1364-2001ext+ --lint-only -Wall -Wno-fatal -Wno-DECLFILENAME \
                ${gcmRtl}/gcm.v ${gcmRtl}/gcm_core.v ${gcmRtl}/gcm_ghash.v ${aesSrcs}
            '';
            installPhase = "touch $out";
          };

          sim-ghash = mkSimCheck "ghash" pkgs'.ghash;
          sim-core  = mkSimCheck "core"  pkgs'.core;
          sim-top   = mkSimCheck "top"   pkgs'.top;
        });
    };
}
