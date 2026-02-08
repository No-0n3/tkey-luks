// SPDX-FileCopyrightText: 2026 TKey-LUKS Project
// SPDX-License-Identifier: BSD-2-Clause
//
// Adapted from tkey-device-signer for LUKS key derivation
// Original: https://github.com/tillitis/tkey-device-signer

#include <monocypher/monocypher-ed25519.h>
#include <stdbool.h>
#include <tkey/assert.h>
#include <tkey/led.h>
#include <tkey/lib.h>
#include <tkey/proto.h>
#include <tkey/qemu_debug.h>
#include <tkey/tk1_mem.h>
#include <tkey/touch.h>

#include "app_proto.h"

// clang-format off
static volatile uint32_t *cdi           = (volatile uint32_t *) TK1_MMIO_TK1_CDI_FIRST;
static volatile uint32_t *cpu_mon_ctrl  = (volatile uint32_t *) TK1_MMIO_TK1_CPU_MON_CTRL;
static volatile uint32_t *cpu_mon_first = (volatile uint32_t *) TK1_MMIO_TK1_CPU_MON_FIRST;
static volatile uint32_t *cpu_mon_last  = (volatile uint32_t *) TK1_MMIO_TK1_CPU_MON_LAST;
static volatile uint32_t *app_addr      = (volatile uint32_t *) TK1_MMIO_TK1_APP_ADDR;
static volatile uint32_t *app_size      = (volatile uint32_t *) TK1_MMIO_TK1_APP_SIZE;
// clang-format on

// Touch timeout in seconds
#define TOUCH_TIMEOUT 30
#define MAX_CHALLENGE_SIZE 256

const uint8_t app_name0[4] = "tk1 ";
const uint8_t app_name1[4] = "luks";
const uint32_t app_version = 0x00000001;

enum state {
	STATE_STARTED,
	STATE_LOADING,
	STATE_DERIVING,
	STATE_FAILED,
};

// Context for the loading of a challenge
struct context {
	uint8_t secret_key[64]; // Private key derived from CDI. Keep this
				// BEFORE challenge buffer for security.
	uint8_t pubkey[32];
	uint8_t challenge[MAX_CHALLENGE_SIZE];
	uint32_t left; // Bytes left to receive
	uint32_t challenge_size;
	uint16_t challenge_idx; // Where we are currently loading
};

// Incoming packet from client
struct packet {
	struct frame_header hdr;      // Framing Protocol header
	uint8_t cmd[CMDLEN_MAXBYTES]; // Application level protocol
};

static enum state started_commands(enum state state, struct context *ctx,
				   struct packet pkt);
static enum state loading_commands(enum state state, struct context *ctx,
				   struct packet pkt);
static enum state deriving_commands(enum state state, struct context *ctx,
				    struct packet pkt);
static int read_command(struct frame_header *hdr, uint8_t *cmd);
static void wipe_context(struct context *ctx);

static void wipe_context(struct context *ctx)
{
	crypto_wipe(ctx->challenge, MAX_CHALLENGE_SIZE);
	ctx->left = 0;
	ctx->challenge_size = 0;
	ctx->challenge_idx = 0;
}

// started_commands() allows only these commands:
//
// - CMD_FW_PROBE
// - CMD_GET_NAMEVERSION
// - CMD_GET_FIRMWARE_HASH
// - CMD_GET_PUBKEY
// - CMD_SET_CHALLENGE
//
// Anything else sent leads to state 'failed'.
//
// Arguments: the current state, the context and the incoming command.
// Returns: The new state.
static enum state started_commands(enum state state, struct context *ctx,
				   struct packet pkt)
{
	uint8_t rsp[CMDLEN_MAXBYTES] = {0}; // Response
	size_t rsp_left =
	    CMDLEN_MAXBYTES; // How many bytes left in response buf

	qemu_puts("started_commands, command: ");
	qemu_putinthex(pkt.cmd[0]);
	qemu_lf();

	// Smallest possible payload length (cmd) is 1 byte.
	switch (pkt.cmd[0]) {
	case CMD_FW_PROBE:
		// Firmware probe. Allowed in this protocol state.
		// State unchanged.
		break;

	case CMD_GET_NAMEVERSION:
		qemu_puts("CMD_GET_NAMEVERSION\n");
		if (pkt.hdr.len != 1) {
			// Bad length
			state = STATE_FAILED;
			break;
		}

	memcpy_s(rsp, rsp_left, app_name0, sizeof(app_name0));
	rsp_left -= sizeof(app_name0);

	memcpy_s(&rsp[4], rsp_left, app_name1, sizeof(app_name1));
	rsp_left -= sizeof(app_name1);

	memcpy_s(&rsp[8], rsp_left, &app_version, sizeof(app_version));

		appreply(pkt.hdr, RSP_GET_NAMEVERSION, rsp);

		// state unchanged
		break;

	case CMD_GET_FIRMWARE_HASH: {
		uint32_t fw_len = 0;

		qemu_puts("CMD_GET_FIRMWARE_HASH\n");
		if (pkt.hdr.len != 32) {
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_GET_FIRMWARE_HASH, rsp);

			state = STATE_FAILED;
			break;
		}

		fw_len = pkt.cmd[1] + (pkt.cmd[2] << 8) + (pkt.cmd[3] << 16) +
			 (pkt.cmd[4] << 24);

		if (fw_len == 0 || fw_len > 8192) {
			qemu_puts("FW size must be > 0 and <= 8192\n");
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_GET_FIRMWARE_HASH, rsp);

			state = STATE_FAILED;
			break;
		}

		rsp[0] = STATUS_OK;
		crypto_sha512(&rsp[1], (void *)TK1_ROM_BASE, fw_len);
		appreply(pkt.hdr, RSP_GET_FIRMWARE_HASH, rsp);

		// state unchanged
		break;
	}

	case CMD_GET_PUBKEY:
		qemu_puts("CMD_GET_PUBKEY\n");
		if (pkt.hdr.len != 1) {
			// Bad length
			state = STATE_FAILED;
			break;
		}

		memcpy_s(rsp, CMDLEN_MAXBYTES, ctx->pubkey,
			 sizeof(ctx->pubkey));

		appreply(pkt.hdr, RSP_GET_PUBKEY, rsp);

		// state unchanged
		break;

	case CMD_SET_CHALLENGE: {
		uint32_t local_challenge_size = 0;

		qemu_puts("CMD_SET_CHALLENGE\n");
		// Bad length - expecting 32 bytes (1 cmd + 4 size + padding)
		if (pkt.hdr.len != 32) {
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_SET_CHALLENGE, rsp);

			state = STATE_FAILED;
			break;
		}

		// cmd[1..4] contains the size.
		local_challenge_size = pkt.cmd[1] + (pkt.cmd[2] << 8) +
				       (pkt.cmd[3] << 16) + (pkt.cmd[4] << 24);

		if (local_challenge_size == 0 ||
		    local_challenge_size > MAX_CHALLENGE_SIZE) {
			qemu_puts("Challenge size not within range!\n");
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_SET_CHALLENGE, rsp);

			state = STATE_FAILED;
			break;
		}

		// Set the real challenge size used later and reset
		// where we load the data
		ctx->challenge_size = local_challenge_size;
		ctx->left = ctx->challenge_size;
		ctx->challenge_idx = 0;

		rsp[0] = STATUS_OK;
		appreply(pkt.hdr, RSP_SET_CHALLENGE, rsp);

		state = STATE_LOADING;
		break;
	}

	default:
		qemu_puts("Got unknown initial command: 0x");
		qemu_puthex(pkt.cmd[0]);
		qemu_lf();

		state = STATE_FAILED;
		break;
	}

	return state;
}

// loading_commands() allows only these commands:
//
// - CMD_LOAD_CHALLENGE
//
// Anything else sent leads to state 'failed'.
//
// Arguments: the current state, the context and the incoming command.
// Returns: The new state.
static enum state loading_commands(enum state state, struct context *ctx,
				   struct packet pkt)
{
	uint8_t rsp[CMDLEN_MAXBYTES] = {0}; // Response
	int nbytes = 0;			    // Bytes to write to memory

	switch (pkt.cmd[0]) {
	case CMD_LOAD_CHALLENGE: {
		qemu_puts("CMD_LOAD_CHALLENGE\n");

		// Bad length
		if (pkt.hdr.len != CMDLEN_MAXBYTES) {
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_LOAD_CHALLENGE, rsp);

			state = STATE_FAILED;
			break;
		}

		if (ctx->left > CMDLEN_MAXBYTES - 1) {
			nbytes = CMDLEN_MAXBYTES - 1;
		} else {
			nbytes = ctx->left;
		}

		memcpy_s(&ctx->challenge[ctx->challenge_idx],
			 MAX_CHALLENGE_SIZE - ctx->challenge_idx, pkt.cmd + 1,
			 nbytes);

		ctx->challenge_idx += nbytes;
		ctx->left -= nbytes;

		rsp[0] = STATUS_OK;
		appreply(pkt.hdr, RSP_LOAD_CHALLENGE, rsp);

		if (ctx->left == 0) {

			state = STATE_DERIVING;
			break;
		}

		// state unchanged
		break;
	}

	default:
		qemu_puts("Got unknown loading command: 0x");
		qemu_puthex(pkt.cmd[0]);
		qemu_lf();

		state = STATE_FAILED;
		break;
	}

	return state;
}

// deriving_commands() allows only these commands:
//
// - CMD_DERIVE_KEY
//
// Anything else sent leads to state 'failed'.
//
// Arguments: the current state, the context, the incoming command
// packet.
//
// Returns: The new state.
static enum state deriving_commands(enum state state, struct context *ctx,
				    struct packet pkt)
{
	uint8_t rsp[CMDLEN_MAXBYTES] = {0}; // Response
	uint8_t derived_key[64] = {0};
	bool touched = false;

	switch (pkt.cmd[0]) {
	case CMD_DERIVE_KEY:
		qemu_puts("CMD_DERIVE_KEY\n");
		if (pkt.hdr.len != 1) {
			// Bad length
			state = STATE_FAILED;
			break;
		}

#ifndef TKEY_LUKS_APP_NO_TOUCH
		touched = touch_wait(LED_GREEN, TOUCH_TIMEOUT);

		if (!touched) {
			rsp[0] = STATUS_BAD;
			appreply(pkt.hdr, RSP_DERIVE_KEY, rsp);

			state = STATE_STARTED;
			break;
		}
#endif
		qemu_puts("Touched, now deriving key\n");

		// All loaded, device touched, let's derive the LUKS key
		// Use BLAKE2b as key derivation function:
		// - Input: challenge from initramfs
		// - Key: secret_key (derived from CDI+USS)
		// - Output: 64-byte key for LUKS
		crypto_blake2b_keyed(derived_key, sizeof(derived_key),
				     ctx->secret_key, sizeof(ctx->secret_key),
				     ctx->challenge, ctx->challenge_size);

		qemu_puts("Sending derived key!\n");
		memcpy_s(rsp + 1, CMDLEN_MAXBYTES, derived_key,
			 sizeof(derived_key));
		appreply(pkt.hdr, RSP_DERIVE_KEY, rsp);

		// Forget derived key and challenge context
		crypto_wipe(derived_key, sizeof(derived_key));
		wipe_context(ctx);

		state = STATE_STARTED;
		break;
	}

	return state;
}

// read_command takes a frame header and a command to fill in after
// parsing. It returns 0 on success.
static int read_command(struct frame_header *hdr, uint8_t *cmd)
{
	uint8_t in = 0;

	memset(hdr, 0, sizeof(struct frame_header));
	memset(cmd, 0, CMDLEN_MAXBYTES);

	in = readbyte();

	if (parseframe(in, hdr) == -1) {
		qemu_puts("Couldn't parse header\n");
		return -1;
	}

	// Now we know the size of the cmd frame, read it all
	if (read(cmd, CMDLEN_MAXBYTES, hdr->len) != 0) {
		qemu_puts("read: buffer overrun\n");
		return -1;
	}

	// Well-behaved apps are supposed to check for a client
	// attempting to probe for firmware. In that case destination
	// is firmware and we just reply NOK.
	if (hdr->endpoint == DST_FW) {
		appreply_nok(*hdr);
		qemu_puts("Responded NOK to message meant for fw\n");
		cmd[0] = CMD_FW_PROBE;
		return 0;
	}

	// Is it for us?
	if (hdr->endpoint != DST_SW) {
		qemu_puts("Message not meant for app. endpoint was 0x");
		qemu_puthex(hdr->endpoint);
		qemu_lf();

		return -1;
	}

	return 0;
}

int main(void)
{
	struct context ctx = {0};
	enum state state = STATE_STARTED;
	struct packet pkt = {0};

	// Use Execution Monitor on RAM after app
	*cpu_mon_first = *app_addr + *app_size;
	*cpu_mon_last = TK1_RAM_BASE + TK1_RAM_SIZE;
	*cpu_mon_ctrl = 1;

	led_set(LED_BLUE);

#ifdef TKEY_DEBUG
	config_endpoints(IO_CDC | IO_DEBUG);
#endif

	// Generate a public key from CDI
	crypto_ed25519_key_pair(ctx.secret_key, ctx.pubkey, (uint8_t *)cdi);

	for (;;) {
		qemu_puts("parser state: ");
		qemu_putinthex(state);
		qemu_lf();

		if (read_command(&pkt.hdr, pkt.cmd) != 0) {
			qemu_puts("read_command returned != 0!\n");
			state = STATE_FAILED;
		}

		switch (state) {
		case STATE_STARTED:
			state = started_commands(state, &ctx, pkt);
			break;

		case STATE_LOADING:
			state = loading_commands(state, &ctx, pkt);
			break;

		case STATE_DERIVING:
			state = deriving_commands(state, &ctx, pkt);
			break;

		case STATE_FAILED:
			// fallthrough

		default:
			qemu_puts("parser state 0x");
			qemu_puthex(state);
			qemu_lf();
			assert(1 == 2);
			break; // Not reached
		}
	}
}
