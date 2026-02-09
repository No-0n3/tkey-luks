// SPDX-FileCopyrightText: 2022 Tillitis AB <tillitis.se>
// SPDX-FileCopyrightText: 2026 Isaac Caceres
// SPDX-License-Identifier: BSD-2-Clause
//
// Adapted from tkey-device-signer for LUKS key derivation

#include <tkey/qemu_debug.h>

#include "app_proto.h"

// Send reply frame with response status Not OK (NOK==1), shortest length
void appreply_nok(struct frame_header hdr)
{
	writebyte(genhdr(hdr.id, hdr.endpoint, 0x1, LEN_1));
	writebyte(0);
}

// Send app reply with frame header, response code, and LEN_X-1 bytes from buf
void appreply(struct frame_header hdr, enum appcmd rspcode, void *buf)
{
	size_t nbytes = 0;
	enum cmdlen len = LEN_1;

	switch (rspcode) {
	case RSP_GET_PUBKEY:
		len = LEN_128;
		nbytes = 128;
		break;

	case RSP_SET_CHALLENGE:
		len = LEN_4;
		nbytes = 4;
		break;

	case RSP_LOAD_CHALLENGE:
		len = LEN_4;
		nbytes = 4;
		break;

	case RSP_DERIVE_KEY:
		len = LEN_128;
		nbytes = 128;
		break;

	case RSP_GET_NAMEVERSION:
		len = LEN_32;
		nbytes = 32;
		break;

	case RSP_GET_FIRMWARE_HASH:
		len = LEN_128;
		nbytes = 128;
		break;

	default:
		qemu_puts("appreply(): Unknown response code: ");
		qemu_puthex(rspcode);
		qemu_lf();

		return;
	}

	// Frame Protocol Header
	writebyte(genhdr(hdr.id, hdr.endpoint, 0x0, len));

	// app protocol header is 1 byte response code
	writebyte(rspcode);
	nbytes--;

	write(buf, nbytes);
}
