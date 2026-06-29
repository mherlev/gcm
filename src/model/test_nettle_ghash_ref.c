/*
 * test_nettle_ghash_ref.c
 *
 * Driver for the nettle_ghash_ref reference implementation.
 * Computes intermediate GHASH values for NIST SP 800-38D TC2 (AES-128)
 * and TC14 (AES-256) and self-checks TC2 against the published tag.
 *
 * Output values are printed as 32-char lowercase hex strings suitable
 * for direct use as Verilog 128'h<value> literals.
 *
 * Exit code: 0 = all self-checks passed, 1 = at least one failure.
 */

#include "nettle_ghash_ref.h"

#include <stdio.h>
#include <string.h>

static void print_hex(const char *label, const uint8_t *v, size_t len)
{
    printf("  %-36s", label);
    for (size_t i = 0; i < len; i++)
        printf("%02x", v[i]);
    printf("\n");
}

static int bytes_eq(const uint8_t *a, const uint8_t *b, size_t n)
{
    return memcmp(a, b, n) == 0;
}

int main(void)
{
    int failures = 0;

    /* ---------------------------------------------------------------
     * NIST SP 800-38D Test Case 2 (AES-128-GCM, single block)
     * K   = 0^128
     * IV  = 0^96  →  J0 = 0x00000000000000000000000000000001
     * P   = 0^128
     * A   = (empty)
     * C   = 0388dace60b6a392f328c2b971b2fe78
     * Tag = ab6e47d42cec13bdf53a67b21257bddf
     * --------------------------------------------------------------- */

    /* H = AES(K=0, 0^128) = 66e94bd4ef8a2c3b884cfa59ca342b2e */
    static const uint8_t H[16] = {
        0x66, 0xe9, 0x4b, 0xd4, 0xef, 0x8a, 0x2c, 0x3b,
        0x88, 0x4c, 0xfa, 0x59, 0xca, 0x34, 0x2b, 0x2e
    };

    /* C1 = 0388dace60b6a392f328c2b971b2fe78 */
    static const uint8_t C1[16] = {
        0x03, 0x88, 0xda, 0xce, 0x60, 0xb6, 0xa3, 0x92,
        0xf3, 0x28, 0xc2, 0xb9, 0x71, 0xb2, 0xfe, 0x78
    };

    /* len(A)||len(C) = {0, 128 bits} = 0x00000000000000000000000000000080 */
    static const uint8_t len_block[16] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80
    };

    /*
     * E(K=0, J0=0x01) = 58e2fccefa7e3061367f1d57a4e7455a
     * (equals the NIST TC1 tag: TC1 has empty P and empty A,
     *  so tag = GHASH_final XOR E(K,J0) = 0 XOR E(K,J0) = E(K,J0))
     */
    static const uint8_t E_K_J0[16] = {
        0x58, 0xe2, 0xfc, 0xce, 0xfa, 0x7e, 0x30, 0x61,
        0x36, 0x7f, 0x1d, 0x57, 0xa4, 0xe7, 0x45, 0x5a
    };

    static const uint8_t TC2_tag[16] = {
        0xab, 0x6e, 0x47, 0xd4, 0x2c, 0xec, 0x13, 0xbd,
        0xf5, 0x3a, 0x67, 0xb2, 0x12, 0x57, 0xbd, 0xdf
    };

    printf("--- NIST SP 800-38D TC2 (AES-128-GCM) ---\n");

    /* TC-REF01: GHASH after one ciphertext block */
    uint8_t Y1[16];
    nettle_ghash_ref(H, C1, 16, Y1);
    print_hex("GHASH(H, [C1]):", Y1, 16);

    /* TC-REF02: GHASH after ciphertext block then length block */
    uint8_t data2[32];
    memcpy(data2,      C1,        16);
    memcpy(data2 + 16, len_block, 16);
    uint8_t Y2[16];
    nettle_ghash_ref(H, data2, 32, Y2);
    print_hex("GHASH(H, [C1 || len]):", Y2, 16);

    /* Self-check: tag = GHASH_final XOR E(K, J0) */
    uint8_t computed_tag[16];
    for (int i = 0; i < 16; i++)
        computed_tag[i] = (uint8_t)(Y2[i] ^ E_K_J0[i]);

    if (bytes_eq(computed_tag, TC2_tag, 16)) {
        printf("  self-check (Y2 XOR E(K,J0) == TC2 tag): PASS\n");
    } else {
        printf("  self-check: FAIL\n");
        print_hex("  expected tag:", TC2_tag,       16);
        print_hex("  computed tag:", computed_tag,  16);
        failures++;
    }

    /* ---------------------------------------------------------------
     * NIST SP 800-38D Test Case 14 (AES-256-GCM, single block)
     * K   = 0^256
     * IV  = 0^96  →  J0 = 0x00000000000000000000000000000001
     * P   = 0^128
     * A   = (empty)
     * C   = cea7403d4d606b6e074ec5d3baf39d18
     * Tag = d0d1c8a799996bf0265b98b5d48ab919
     * --------------------------------------------------------------- */

    /* H_256 = AES-256(K=0, 0^128) = dc95c078a2408989ad48a21492842087 */
    static const uint8_t H_256[16] = {
        0xdc, 0x95, 0xc0, 0x78, 0xa2, 0x40, 0x89, 0x89,
        0xad, 0x48, 0xa2, 0x14, 0x92, 0x84, 0x20, 0x87
    };

    /* C1_256 = cea7403d4d606b6e074ec5d3baf39d18 */
    static const uint8_t C1_256[16] = {
        0xce, 0xa7, 0x40, 0x3d, 0x4d, 0x60, 0x6b, 0x6e,
        0x07, 0x4e, 0xc5, 0xd3, 0xba, 0xf3, 0x9d, 0x18
    };

    printf("\n--- NIST SP 800-38D TC14 (AES-256-GCM) ---\n");

    /* TC-REF03: GHASH after one ciphertext block */
    uint8_t Y1_256[16];
    nettle_ghash_ref(H_256, C1_256, 16, Y1_256);
    print_hex("GHASH(H_256, [C1]):", Y1_256, 16);

    /* TC-REF04: GHASH after ciphertext block then length block */
    uint8_t data4[32];
    memcpy(data4,      C1_256,    16);
    memcpy(data4 + 16, len_block, 16);
    uint8_t Y2_256[16];
    nettle_ghash_ref(H_256, data4, 32, Y2_256);
    print_hex("GHASH(H_256, [C1 || len]):", Y2_256, 16);
    printf("  (no self-check: E(K_256,J0) not independently known)\n");

    printf("\n%s\n", failures == 0 ? "PASS" : "FAIL");
    return failures;
}
