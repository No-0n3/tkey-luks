// SPDX-FileCopyrightText: 2026 TKey-LUKS Project
// SPDX-License-Identifier: BSD-2-Clause
//
// Adapted from tkey-device-signer for LUKS key derivation

#include <tkey/debug.h>
#include <tkey/tk1_mem.h>

#include "app_proto.h"
#include "platform.h"

// clang-format off
static volatile uint32_t *ver = (volatile uint32_t *) TK1_MMIO_TK1_VERSION;
// clang-format on

// Send reply frame with response status Not OK (NOK==1), shortest length
void appreply_nok(struct frame_header hdr)
{
	uint8_t buf[2];
	enum ioend dst = IO_CDC;

	buf[0] = genhdr(hdr.id, hdr.endpoint, 0x1, LEN_1);
	buf[1] = 0; // Not used, but smallest payload is 1 byte

	if (*ver < CASTORVERSION) {
		dst = IO_UART;
	}

	write(dst, buf, 2);
}

// Send app reply with frame header, response code, and LEN_X-1 bytes from buf
void appreply(struct frame_header hdr, enum appcmd rspcode, void *buf)
{
	size_t nbytes = 0; // Number of bytes in a reply frame
			   // (including rspcode).
	enum cmdlen len = LEN_1;
	uint8_t frame[1 + 128];	 // Frame header + longest response
	enum ioend dst = IO_CDC; // I/O destination.

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
		debug_puts("appreply: Unknown response code: 0x");
		debug_puthex(rspcode);
		debug_lf();

		return;
	}

	if (*ver < CASTORVERSION) {
		dst = IO_UART;
	}

	frame[0] = genhdr(hdr.id, hdr.endpoint, 0x0, len);
	memcpy_s(&frame[1], 128, buf, nbytes);

	write(dst, frame, nbytes + 1);
}
