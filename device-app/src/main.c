/* TKey-LUKS Device Application
 * 
 * This application runs on the Tillitis TKey hardware.
 * It receives challenges from the host and responds with signatures
 * derived from the TKey's unique device secret (USS).
 * 
 * Protocol:
 * 1. Receive challenge (32 bytes)
 * 2. Sign challenge using TKey USS
 * 3. Return signature (64 bytes)
 * 
 * The signature can then be used by the host to derive LUKS keys.
 */

#include <stdint.h>
#include <string.h>

/* TODO: Include TKey SDK headers when submodules are set up
#include "tkey/app.h"
#include "tkey/blake2s.h"
*/

#define CMD_GET_CHALLENGE   0x01
#define CMD_SIGN_CHALLENGE  0x02
#define CMD_GET_PUBKEY      0x03

#define CHALLENGE_SIZE 32
#define SIGNATURE_SIZE 64
#define PUBKEY_SIZE    32

/* Application state */
struct app_state {
    uint8_t challenge[CHALLENGE_SIZE];
    uint8_t signature[SIGNATURE_SIZE];
    uint8_t initialized;
};

static struct app_state state = {0};

/* Function prototypes */
void handle_command(uint8_t cmd, const uint8_t *data, size_t len);
void sign_challenge(const uint8_t *challenge, uint8_t *signature);
void get_device_pubkey(uint8_t *pubkey);

/* Main application entry point */
int main(void) {
    /* TODO: Initialize TKey SDK
     * - Set up communication with host
     * - Initialize cryptographic functions
     * - Get device USS  
     */
    
    state.initialized = 1;
    
    /* Main command loop */
    while (1) {
        uint8_t cmd;
        uint8_t buffer[128];
        size_t len;
        
        /* TODO: Receive command from host
         * cmd = receive_cmd(&buffer, &len);
         */
        
        /* Handle command */
        handle_command(cmd, buffer, len);
    }
    
    return 0;
}

/* Handle incoming commands */
void handle_command(uint8_t cmd, const uint8_t *data, size_t len) {
    (void)len;  /* Unused for now */
    
    switch (cmd) {
    case CMD_GET_CHALLENGE:
        /* Host is sending a challenge to sign */
        if (len == CHALLENGE_SIZE) {
            memcpy(state.challenge, data, CHALLENGE_SIZE);
            /* TODO: Send ACK */
        }
        break;
        
    case CMD_SIGN_CHALLENGE:
        /* Host requests signature of challenge */
        sign_challenge(state.challenge, state.signature);
        /* TODO: Send signature back to host */
        break;
        
    case CMD_GET_PUBKEY:
        /* Host requests device public key (for verification) */
        {
            uint8_t pubkey[PUBKEY_SIZE];
            get_device_pubkey(pubkey);
            /* TODO: Send pubkey back to host */
        }
        break;
        
    default:
        /* Unknown command */
        /* TODO: Send error response */
        break;
    }
}

/* Sign challenge using TKey USS */
void sign_challenge(const uint8_t *challenge, uint8_t *signature) {
    /* TODO: Implement signing using TKey USS
     * 
     * This should:
     * 1. Get TKey Unique Device Secret (USS)
     * 2. Combine USS with challenge
     * 3. Generate signature using Ed25519 or similar
     * 4. Return signature
     * 
     * Example pseudocode:
     *   uss = get_device_uss();
     *   signature = ed25519_sign(uss, challenge);
     * 
     * For now, just copy challenge as placeholder
     */
    memcpy(signature, challenge, CHALLENGE_SIZE);
    memset(signature + CHALLENGE_SIZE, 0, SIGNATURE_SIZE - CHALLENGE_SIZE);
}

/* Get device public key */
void get_device_pubkey(uint8_t *pubkey) {
    /* TODO: Implement public key retrieval
     * 
     * This should:
     * 1. Derive public key from USS
     * 2. Return public key for verification
     * 
     * Example pseudocode:
     *   uss = get_device_uss();
     *   pubkey = ed25519_public_key(uss);
     */
    memset(pubkey, 0, PUBKEY_SIZE);
}

/* Notes for implementation:
 * 
 * The device app should:
 * - Use TKey SDK for hardware access
 * - Leverage USS (Unique Device Secret) for signing
 * - Implement proper cryptographic operations (Ed25519)
 * - Be as small as possible (TKey has limited memory)
 * - Handle errors gracefully
 * 
 * Alternative approach:
 * - Use tkey-sign as base and modify for LUKS use case
 * - This might be simpler than building from scratch
 * 
 * Security considerations:
 * - USS never leaves the device
 * - Signatures are deterministic (same challenge = same signature)
 * - Could add counter/nonce to prevent replay attacks
 */
