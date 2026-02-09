// SPDX-FileCopyrightText: 2022 Tillitis AB <tillitis.se>
// SPDX-FileCopyrightText: 2026 Isaac Caceres
// SPDX-License-Identifier: BSD-2-Clause
// 
// Adapted from tkey-device-signer for LUKS key derivation

#ifndef APP_PROTO_H
#define APP_PROTO_H

#include <tkey/lib.h>
#include <tkey/proto.h>

// clang-format off
enum appcmd {
	CMD_GET_PUBKEY        = 0x01,
	RSP_GET_PUBKEY        = 0x02,
	CMD_SET_CHALLENGE     = 0x03,  // Was: CMD_SET_SIZE
	RSP_SET_CHALLENGE     = 0x04,  // Was: RSP_SET_SIZE
	CMD_LOAD_CHALLENGE    = 0x05,  // Was: CMD_LOAD_DATA
	RSP_LOAD_CHALLENGE    = 0x06,  // Was: RSP_LOAD_DATA
	CMD_DERIVE_KEY        = 0x07,  // Was: CMD_GET_SIG
	RSP_DERIVE_KEY        = 0x08,  // Was: RSP_GET_SIG
	CMD_GET_NAMEVERSION   = 0x09,
	RSP_GET_NAMEVERSION   = 0x0a,
	CMD_GET_FIRMWARE_HASH = 0x0b,
	RSP_GET_FIRMWARE_HASH = 0x0c,

	CMD_FW_PROBE          = 0xff,
};
// clang-format on

void appreply_nok(struct frame_header hdr);
void appreply(struct frame_header hdr, enum appcmd rspcode, void *buf);

#endif
