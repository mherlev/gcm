GCM
===
Galois Counter Mode block cipher mode for AES as specified in NIST SP
800-38D [1], compatible with RFC 5288 [2].


## Introduction ##

This implementation supports 128-bit and 256-bit AES keys and produces
a 128-bit authentication tag.


## Status ##

Functional. Verified against NIST SP 800-38D Appendix B test vectors.

Implemented and passing:

- AES-128-GCM and AES-256-GCM encryption (NIST TC2 and TC14)
- Authentication tag generation (GHASH finalisation + E(K, J0) XOR)
- GHASH accumulator (`gcm_ghash.v`) with full GF(2^128) multiply
- Register bus interface for key, nonce, plaintext, ciphertext, and tag
- Nix flake build: simulation targets, lint check, and C reference model

The C reference model (`src/model/nettle_ghash_ref.c`, extracted from
GNU Nettle) independently cross-checks the GHASH multiplication path.

NIST test vectors verified end-to-end:

| Test Case    | Key     | Ciphertext         | Tag                |
|--------------|---------|--------------------|--------------------|
| TC2 (AES-128)  | `0^128` | `0388dace...fe78`  | `ab6e47d4...bddf`  |
| TC14 (AES-256) | `0^256` | `cea7403d...9d18`  | `d0d1c8a7...b919`  |


## Implementation results ##

Nothing yet.



## References ##

[1] Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode
(GCM) and GMAC
http://csrc.nist.gov/publications/nistpubs/800-38D/SP-800-38D.pdf

[2] IETF. AES Galois Counter Mode (GCM) Cipher Suites for TLS. RFC5288.
https://tools.ietf.org/html/rfc5288

[3] The Galois/Counter Mode of Operation (GCM):
http://csrc.nist.gov/groups/ST/toolkit/BCM/documents/proposedmodes/gcm/gcm-revised-spec.pdf

[4] MACsecGCM-AESTestVectors.
http://www.ieee802.org/1/files/public/docs2011/bn-randall-test-vectors-0511-v1.pdf
