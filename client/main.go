// SPDX-FileCopyrightText: 2025 Isaac Caceres
// SPDX-License-Identifier: BSD-2-Clause

package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/tillitis/tkeyclient"
	"golang.org/x/crypto/pbkdf2"
)

// TKey-LUKS protocol command codes
const (
	cmdSetChallengeCode  = 0x03
	rspSetChallengeCode  = 0x04
	cmdLoadChallengeCode = 0x05
	rspLoadChallengeCode = 0x06
	cmdDeriveKeyCode     = 0x07
	rspDeriveKeyCode     = 0x08
	cmdGetNameVerCode    = 0x09
	rspGetNameVerCode    = 0x0a

	// Status codes
	statusOK  = 0
	statusBad = 1

	// Device app info
	nameApp0 = "tk1 "
	nameApp1 = "luks"
	wantVer  = 1

	// Challenge size (max 256 bytes)
	maxChallengeSize = 256
	chunkSize        = 127 // Max payload per frame
)

// Command types implementing tkeyclient.Cmd interface
type (
	CmdSetChallenge  struct{}
	RspSetChallenge  struct{}
	CmdLoadChallenge struct{}
	RspLoadChallenge struct{}
	CmdDeriveKey     struct{}
	RspDeriveKey     struct{}
	CmdGetNameVer    struct{}
	RspGetNameVer    struct{}
)

// Implement Cmd interface for each command
func (CmdSetChallenge) Code() byte                    { return cmdSetChallengeCode }
func (CmdSetChallenge) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen32 }
func (CmdSetChallenge) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (CmdSetChallenge) String() string                { return "cmdSetChallenge" }

func (RspSetChallenge) Code() byte                    { return rspSetChallengeCode }
func (RspSetChallenge) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen4 }
func (RspSetChallenge) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (RspSetChallenge) String() string                { return "rspSetChallenge" }

func (CmdLoadChallenge) Code() byte                    { return cmdLoadChallengeCode }
func (CmdLoadChallenge) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen128 }
func (CmdLoadChallenge) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (CmdLoadChallenge) String() string                { return "cmdLoadChallenge" }

func (RspLoadChallenge) Code() byte                    { return rspLoadChallengeCode }
func (RspLoadChallenge) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen4 }
func (RspLoadChallenge) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (RspLoadChallenge) String() string                { return "rspLoadChallenge" }

func (CmdDeriveKey) Code() byte                    { return cmdDeriveKeyCode }
func (CmdDeriveKey) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen1 }
func (CmdDeriveKey) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (CmdDeriveKey) String() string                { return "cmdDeriveKey" }

func (RspDeriveKey) Code() byte                    { return rspDeriveKeyCode }
func (RspDeriveKey) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen128 }
func (RspDeriveKey) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (RspDeriveKey) String() string                { return "rspDeriveKey" }

func (CmdGetNameVer) Code() byte                    { return cmdGetNameVerCode }
func (CmdGetNameVer) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen1 }
func (CmdGetNameVer) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (CmdGetNameVer) String() string                { return "cmdGetNameVer" }

func (RspGetNameVer) Code() byte                    { return rspGetNameVerCode }
func (RspGetNameVer) CmdLen() tkeyclient.CmdLen     { return tkeyclient.CmdLen32 }
func (RspGetNameVer) Endpoint() tkeyclient.Endpoint { return tkeyclient.DestApp }
func (RspGetNameVer) String() string                { return "rspGetNameVer" }

var (
	le = log.New(os.Stderr, "", 0)
	
	// Command instances
	cmdSetChallenge  = CmdSetChallenge{}
	rspSetChallenge  = RspSetChallenge{}
	cmdLoadChallenge = CmdLoadChallenge{}
	rspLoadChallenge = RspLoadChallenge{}
	cmdDeriveKey     = CmdDeriveKey{}
	rspDeriveKey     = RspDeriveKey{}
	cmdGetNameVer    = CmdGetNameVer{}
	rspGetNameVer    = RspGetNameVer{}
)

const (
	// USS derivation defaults
	defaultPBKDF2Iterations = 100000
	ussLength               = 32
)

// TKeyLUKS represents a connection to the TKey-LUKS device app
type TKeyLUKS struct {
	tk *tkeyclient.TillitisKey
}

// Connect opens a connection to the TKey
func Connect(devPath string, speed int) (*TKeyLUKS, error) {
	if devPath == "" {
		var err error
		devPath, err = tkeyclient.DetectSerialPort(false)
		if err != nil {
			return nil, fmt.Errorf("DetectSerialPort: %w", err)
		}
	}

	tk := tkeyclient.New()
	le.Printf("Connecting to TKey on %s...", devPath)
	if err := tk.Connect(devPath, tkeyclient.WithSpeed(speed)); err != nil {
		return nil, fmt.Errorf("Connect: %w", err)
	}

	tkey := &TKeyLUKS{tk: tk}
	return tkey, nil
}

// Close closes the connection to the TKey
func (t *TKeyLUKS) Close() error {
	if t.tk != nil {
		return t.tk.Close()
	}
	return nil
}

// LoadApp loads the device app binary to the TKey
func (t *TKeyLUKS) LoadApp(appBinary []byte, uss []byte) error {
	le.Printf("Loading TKey-LUKS device app (%d bytes)...", len(appBinary))

	// Load the app using tkeyclient
	if err := t.tk.LoadApp(appBinary, uss); err != nil {
		return fmt.Errorf("LoadApp: %w", err)
	}

	le.Printf("Device app loaded successfully")
	return nil
}

// GetAppNameVersion gets the app name and version
func (t *TKeyLUKS) GetAppNameVersion() error {
	id := 2  // Use frame ID 2 like tkeysign does
	tx, err := tkeyclient.NewFrameBuf(cmdGetNameVer, id)
	if err != nil {
		return fmt.Errorf("NewFrameBuf: %w", err)
	}

	// Manual hex dump
	le.Printf("TX bytes: % x", tx)

	le.Printf("Sending GetAppNameVersion command (frame ID %d)...", id)
	tkeyclient.Dump("GetAppNameVersion tx", tx)
	if err = t.tk.Write(tx); err != nil {
		return fmt.Errorf("Write: %w", err)
	}

	le.Printf("Waiting for GetAppNameVersion response...")

	// Set timeout for response like tkeysign does
	t.tk.SetReadTimeoutNoErr(2)
	defer t.tk.SetReadTimeoutNoErr(0)

	rx, _, err := t.tk.ReadFrame(rspGetNameVer, id)
	if err != nil {
		return fmt.Errorf("ReadFrame: %w", err)
	}

	tkeyclient.Dump("GetAppNameVersion rx", rx)

	// Response payload starts at rx[2] (after header and response code)
	if len(rx) < 2+12 {
		return fmt.Errorf("response too short: %d bytes", len(rx))
	}

	name0 := string(rx[2:6])
	name1 := string(rx[6:10])
	version := uint32(rx[10]) + (uint32(rx[11]) << 8) +
		(uint32(rx[12]) << 16) + (uint32(rx[13]) << 24)

	if name0 != nameApp0 || name1 != nameApp1 {
		return fmt.Errorf("unexpected app name: %q %q", name0, name1)
	}

	if version != wantVer {
		return fmt.Errorf("unexpected app version: %d (want %d)", version, wantVer)
	}

	le.Printf("Device app verified: %s%s v%d", name0, name1, version)
	return nil
}

// SetChallenge sets the size of the challenge
func (t *TKeyLUKS) SetChallenge(size int) error {
	if size <= 0 || size > maxChallengeSize {
		return fmt.Errorf("invalid challenge size: %d (must be 1-%d)", size, maxChallengeSize)
	}

	id := 2
	tx, err := tkeyclient.NewFrameBuf(cmdSetChallenge, id)
	if err != nil {
		return fmt.Errorf("NewFrameBuf: %w", err)
	}

	// Payload: 4-byte size (little-endian) + padding to 32 bytes total
	// tx[0] = header, tx[1] = cmd code, tx[2:] = payload
	tx[2] = byte(size)
	tx[3] = byte(size >> 8)
	tx[4] = byte(size >> 16)
	tx[5] = byte(size >> 24)
	// Rest is zero-padded by NewFrameBuf

	tkeyclient.Dump("SetChallenge tx", tx)
	if err := t.tk.Write(tx); err != nil {
		return fmt.Errorf("Write: %w", err)
	}

	rx, _, err := t.tk.ReadFrame(rspSetChallenge, id)
	if err != nil {
		return fmt.Errorf("ReadFrame: %w", err)
	}

	tkeyclient.Dump("SetChallenge rx", rx)

	// Status is at rx[2] (after header and response code)
	if len(rx) < 3 || rx[2] != statusOK {
		return fmt.Errorf("device returned error status")
	}

	le.Printf("Challenge size set: %d bytes", size)
	return nil
}

// LoadChallenge sends the challenge data in chunks
func (t *TKeyLUKS) LoadChallenge(challenge []byte) error {
	if len(challenge) == 0 || len(challenge) > maxChallengeSize {
		return fmt.Errorf("invalid challenge length: %d", len(challenge))
	}

	offset := 0
	id := 2

	for offset < len(challenge) {
		// Calculate chunk size
		remaining := len(challenge) - offset
		chunk := chunkSize
		if remaining < chunk {
			chunk = remaining
		}

		// Create frame with pre-sized buffer (1 header + 128 payload)
		tx, err := tkeyclient.NewFrameBuf(cmdLoadChallenge, id)
		if err != nil {
			return fmt.Errorf("NewFrameBuf: %w", err)
		}

		// Copy chunk data to payload area (tx[2] onwards, after header and cmd code)
		// tx[0] = header, tx[1] = cmd code, tx[2:] = payload (127 bytes max)
		copy(tx[2:], challenge[offset:offset+chunk])
		// Buffer is already zero-padded by NewFrameBuf

		tkeyclient.Dump("LoadChallenge tx", tx)
		if err = t.tk.Write(tx); err != nil {
			return fmt.Errorf("Write: %w", err)
		}

		rx, _, err := t.tk.ReadFrame(rspLoadChallenge, id)
		if err != nil {
			return fmt.Errorf("ReadFrame: %w", err)
		}

		tkeyclient.Dump("LoadChallenge rx", rx)

		// Status is at rx[2]
		if len(rx) < 3 || rx[2] != statusOK {
			return fmt.Errorf("device returned error status")
		}

		offset += chunk
		le.Printf("Loaded challenge chunk: %d/%d bytes", offset, len(challenge))
	}

	return nil
}

// DeriveKey requests the device to derive the LUKS key
// Returns the 64-byte derived key
func (t *TKeyLUKS) DeriveKey() ([]byte, error) {
	id := 2
	tx, err := tkeyclient.NewFrameBuf(cmdDeriveKey, id)
	if err != nil {
		return nil, fmt.Errorf("NewFrameBuf: %w", err)
	}

	le.Printf("Requesting key derivation (please touch TKey)...")

	tkeyclient.Dump("DeriveKey tx", tx)
	if err = t.tk.Write(tx); err != nil {
		return nil, fmt.Errorf("Write: %w", err)
	}

	rx, _, err := t.tk.ReadFrame(rspDeriveKey, id)
	if err != nil {
		return nil, fmt.Errorf("ReadFrame: %w", err)
	}

	tkeyclient.Dump("DeriveKey rx", rx)

	// Response: rx[0]=header, rx[1]=rsp code, rx[2]=status, rx[3:67]=64-byte key
	if len(rx) < 2+1+64 {
		return nil, fmt.Errorf("response too short: %d bytes (expected %d)", len(rx), 2+1+64)
	}

	if rx[2] != statusOK {
		return nil, fmt.Errorf("device returned error status")
	}

	key := make([]byte, 64)
	copy(key, rx[3:3+64])
	le.Printf("Key derived successfully (%d bytes)", len(key))

	return key, nil
}

// UnlockLUKS uses cryptsetup to unlock a LUKS volume with the derived key
func UnlockLUKS(keyfile string, luksImage string, mapperName string) error {
	cmd := exec.Command("sudo", "cryptsetup", "luksOpen", luksImage, mapperName, "--key-file", keyfile)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cryptsetup failed: %w\nOutput: %s", err, string(output))
	}

	le.Printf("LUKS volume unlocked: /dev/mapper/%s", mapperName)
	return nil
}

func usage() {
	fmt.Fprintf(os.Stderr, `Usage:

%s [flags]

Derive a key from TKey and optionally unlock a LUKS volume.

Flags:
  --challenge STRING       Challenge string for key derivation
  --challenge-from-stdin   Read challenge from stdin (for piping)
  --luks-image PATH        Path to LUKS image to unlock
  --mapper-name NAME       Device mapper name (default: tkey-luks)
  --app PATH               Path to device app binary
  --device PATH            TKey device path (default: /dev/ttyACM0)
  --skip-load-app          Skip loading app (use if app already loaded)
  --port PATH              TKey serial port (default: auto-detect)
  --speed BPS              Serial port speed (default: 62500)

USS Options (User Supplied Secret):
  --derive-uss             Derive USS from password using PBKDF2 (RECOMMENDED)
  --uss-password TEXT      Password for USS derivation (defaults to challenge)
  --uss-password-stdin     Read USS password from stdin
  --salt TEXT              Custom salt for USS derivation (auto-detected if not provided)
  --pbkdf2-iterations N    PBKDF2 iterations (default: 100000)
  --uss PATH               [DEPRECATED] Load USS from file (insecure)

Output Options:
  --save-key FILE          Save derived key to file
  --output FILE            Output key to file (use '-' for stdout)

Other Options:
  --verbose                Enable verbose output
  --help                   Show this help

Examples:
  # Unlock LUKS volume with challenge
  %s --challenge "my-system-id" --luks-image /dev/sda2

  # Unlock test image
  %s --challenge "luks-challenge-2024" --luks-image test-luks-100mb.img

  # Derive key from stdin and output to stdout (for piping to cryptsetup)
  echo "my challenge" | %s --challenge-from-stdin --output -

  # Use with cryptsetup directly
  echo "my challenge" | %s --challenge-from-stdin --output - | \
    cryptsetup luksOpen /dev/sda2 root_crypt

  # Save key for later use
  %s --challenge "test" --output keyfile.bin
`, os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0])
}

// findDeviceBinary searches for the device binary in multiple locations
func findDeviceBinary() string {
	const deviceBinary = "tkey-luks-device.bin"
	
	// Try multiple locations in order of preference
	searchPaths := []string{
		// 1. Same directory as the client executable
		"",  // Will be replaced with executable's directory
		// 2. System installation path (from device-app Makefile)
		"/usr/local/lib/tkey-luks/" + deviceBinary,
		// 3. Development path (relative from source)
		"../device-app/" + deviceBinary,
		// 4. Current directory
		"./" + deviceBinary,
	}
	
	// Get executable's directory and use it for first search path
	if exePath, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exePath)
		searchPaths[0] = filepath.Join(exeDir, deviceBinary)
	}
	
	// Search for the binary in each path
	for _, path := range searchPaths {
		if path == "" {
			continue
		}
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	
	// Return development path as fallback (will error later if not found)
	return "../device-app/" + deviceBinary
}

// getSystemSalt attempts to get a unique system identifier for salt
// Priority order: machine-id, hostname, random fallback
func getSystemSalt() ([]byte, error) {
	// Try /etc/machine-id (systemd)
	if data, err := os.ReadFile("/etc/machine-id"); err == nil {
		salt := strings.TrimSpace(string(data))
		if salt != "" {
			le.Printf("Using machine-id for salt")
			return []byte(salt), nil
		}
	}
	
	// Try /var/lib/dbus/machine-id (alternative location)
	if data, err := os.ReadFile("/var/lib/dbus/machine-id"); err == nil {
		salt := strings.TrimSpace(string(data))
		if salt != "" {
			le.Printf("Using dbus machine-id for salt")
			return []byte(salt), nil
		}
	}
	
	// Try DMI product UUID (hardware-based)
	if data, err := os.ReadFile("/sys/class/dmi/id/product_uuid"); err == nil {
		salt := strings.TrimSpace(string(data))
		if salt != "" && salt != "00000000-0000-0000-0000-000000000000" {
			le.Printf("Using DMI product UUID for salt")
			return []byte(salt), nil
		}
	}
	
	// Fallback: use hostname
	hostname, err := os.Hostname()
	if err == nil && hostname != "" && hostname != "localhost" {
		le.Printf("WARNING: Using hostname as salt (not ideal for security)")
		return []byte(hostname), nil
	}
	
	return nil, fmt.Errorf("could not determine system salt")
}

// deriveUSSFromPassword derives a USS from a password using PBKDF2
func deriveUSSFromPassword(password string, salt []byte, iterations int) ([]byte, error) {
	if password == "" {
		return nil, fmt.Errorf("password cannot be empty")
	}
	if len(salt) == 0 {
		return nil, fmt.Errorf("salt cannot be empty")
	}
	if iterations < 10000 {
		return nil, fmt.Errorf("iterations too low (minimum 10000)")
	}
	
	// Use PBKDF2 with SHA-256 to derive USS
	uss := pbkdf2.Key([]byte(password), salt, iterations, ussLength, sha256.New)
	
	if len(uss) != ussLength {
		return nil, fmt.Errorf("derived USS wrong length: %d", len(uss))
	}
	
	return uss, nil
}

func main() {
	var (
		challengeStr       string
		challengeStdin     bool
		luksImage          string
		mapperName         = "tkey-luks"
		appPath            = findDeviceBinary()
		skipLoadApp        bool
		portPath           string
		speed              = tkeyclient.SerialSpeed
		ussPath            string // Deprecated: for backward compatibility
		deriveUSS          bool
		ussPassword        string
		ussPasswordStdin   bool
		saltValue          string
		pbkdf2Iterations   = defaultPBKDF2Iterations
		saveKeyPath        string
		outputPath         string
		verbose            bool
	)

	// Simple flag parsing
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--challenge":
			if i+1 >= len(args) {
				le.Fatal("--challenge requires an argument")
			}
			challengeStr = args[i+1]
			i++
		case "--challenge-from-stdin":
			challengeStdin = true
		case "--luks-image":
			if i+1 >= len(args) {
				le.Fatal("--luks-image requires an argument")
			}
			luksImage = args[i+1]
			i++
		case "--mapper-name":
			if i+1 >= len(args) {
				le.Fatal("--mapper-name requires an argument")
			}
			mapperName = args[i+1]
			i++
		case "--app":
			if i+1 >= len(args) {
				le.Fatal("--app requires an argument")
			}
			appPath = args[i+1]
			i++
		case "--device-app":
			// Alias for --app
			if i+1 >= len(args) {
				le.Fatal("--device-app requires an argument")
			}
			appPath = args[i+1]
			i++
		case "--port":
			if i+1 >= len(args) {
				le.Fatal("--port requires an argument")
			}
			portPath = args[i+1]
			i++
		case "--device":
			// Alias for --port
			if i+1 >= len(args) {
				le.Fatal("--device requires an argument")
			}
			portPath = args[i+1]
			i++
		case "--speed":
			if i+1 >= len(args) {
				le.Fatal("--speed requires an argument")
			}
			fmt.Sscanf(args[i+1], "%d", &speed)
			i++
		case "--uss":
			// Deprecated: kept for backward compatibility
			if i+1 >= len(args) {
				le.Fatal("--uss requires an argument")
			}
			ussPath = args[i+1]
			i++
		case "--derive-uss":
			deriveUSS = true
		case "--uss-password":
			if i+1 >= len(args) {
				le.Fatal("--uss-password requires an argument")
			}
			ussPassword = args[i+1]
			i++
		case "--uss-password-stdin":
			ussPasswordStdin = true
		case "--salt":
			if i+1 >= len(args) {
				le.Fatal("--salt requires an argument")
			}
			saltValue = args[i+1]
			i++
		case "--pbkdf2-iterations":
			if i+1 >= len(args) {
				le.Fatal("--pbkdf2-iterations requires an argument")
			}
			fmt.Sscanf(args[i+1], "%d", &pbkdf2Iterations)
			i++
		case "--save-key":
			if i+1 >= len(args) {
				le.Fatal("--save-key requires an argument")
			}
			saveKeyPath = args[i+1]
			i++
		case "--output":
			if i+1 >= len(args) {
				le.Fatal("--output requires an argument")
			}
			outputPath = args[i+1]
			i++
		case "--skip-load-app":
			skipLoadApp = true
		case "--verbose":
			verbose = true
		case "--help", "-h":
			usage()
			os.Exit(0)
		default:
			le.Fatalf("Unknown flag: %s\n\nUse --help for usage", args[i])
		}
	}

	// Read challenge from stdin if requested
	if challengeStdin {
		if verbose {
			le.Printf("Reading challenge from stdin...")
		}
		stdinData, err := io.ReadAll(os.Stdin)
		if err != nil {
			le.Fatalf("Failed to read from stdin: %v", err)
		}
		challengeStr = string(bytes.TrimSpace(stdinData))
		if challengeStr == "" {
			le.Fatal("Empty challenge received from stdin")
		}
	}

	if challengeStr == "" {
		le.Fatal("--challenge or --challenge-from-stdin is required\n\nUse --help for usage")
	}

	// At least one output method must be specified
	if luksImage == "" && saveKeyPath == "" && outputPath == "" {
		le.Fatal("At least one of --luks-image, --save-key, or --output is required\n\nUse --help for usage")
	}

	if !verbose {
		tkeyclient.SilenceLogging()
	} else {
		le.Printf("Using device app from: %s", appPath)
	}

	// Load device app binary
	appBinary, err := os.ReadFile(appPath)
	if err != nil {
		le.Fatalf("Failed to read device app from %s: %v\n\n"+
			"The device app can be:\n"+
			"  - Built in ../device-app/ (for development)\n"+
			"  - Installed to /usr/local/lib/tkey-luks/ (via 'make install' in device-app/)\n"+
			"  - Specified with --app PATH\n",
			appPath, err)
	}

	// Handle USS: either derive from password or load from file
	var uss []byte
	
	if deriveUSS {
		// Improved mode: derive USS from password
		le.Printf("Using improved USS derivation from password")
		
		// Get USS password (can be same as challenge or different)
		if ussPasswordStdin {
			if verbose {
				le.Printf("Reading USS password from stdin...")
			}
			stdinData, err := io.ReadAll(os.Stdin)
			if err != nil {
				le.Fatalf("Failed to read USS password from stdin: %v", err)
			}
			ussPassword = string(bytes.TrimSpace(stdinData))
		} else if ussPassword == "" {
			// Default: use challenge password for USS derivation
			ussPassword = challengeStr
			le.Printf("Using challenge password for USS derivation (recommended)")
		}
		
		if ussPassword == "" {
			le.Fatal("USS password cannot be empty")
		}
		
		// Get or detect salt
		var salt []byte
		if saltValue != "" {
			salt = []byte(saltValue)
			le.Printf("Using provided salt")
		} else {
			salt, err = getSystemSalt()
			if err != nil {
				le.Fatalf("Failed to get system salt: %v\n\nYou can provide a custom salt with --salt", err)
			}
		}
		
		// Derive USS
		uss, err = deriveUSSFromPassword(ussPassword, salt, pbkdf2Iterations)
		if err != nil {
			le.Fatalf("Failed to derive USS: %v", err)
		}
		
		if verbose {
			le.Printf("USS derived successfully using PBKDF2 (%d iterations)", pbkdf2Iterations)
			le.Printf("USS (hex): %s", hex.EncodeToString(uss))
		}
	} else if ussPath != "" {
		// Backward compatibility: load USS from file (DEPRECATED)
		le.Printf("WARNING: Loading USS from file is deprecated and insecure!")
		le.Printf("WARNING: Consider using --derive-uss instead")
		uss, err = os.ReadFile(ussPath)
		if err != nil {
			le.Fatalf("Failed to read USS file: %v", err)
		}
		if len(uss) != 32 {
			le.Fatalf("USS must be 32 bytes, got %d", len(uss))
		}
		le.Printf("Using USS from %s", ussPath)
	} else {
		// No USS (original behavior, least secure)
		le.Printf("WARNING: No USS provided (--derive-uss or --uss)")
		le.Printf("WARNING: For better security, use --derive-uss")
	}

	// Connect to TKey
	tkey, err := Connect(portPath, speed)
	if err != nil {
		le.Fatalf("Failed to connect: %v", err)
	}
	defer tkey.Close()

	// Load device app (unless skipped)
	if !skipLoadApp {
		if err := tkey.LoadApp(appBinary, uss); err != nil {
			le.Fatalf("Failed to load app: %v", err)
		}

		// Give the device app time to initialize
		// The ed25519 keypair generation from CDI takes time (~100-200ms)
		// and the app doesn't respond until it enters the command loop
		le.Printf("Waiting for device app to initialize...")
		time.Sleep(2 * time.Second)
	} else {
		le.Printf("Skipping app load (using pre-loaded app)")
	}

	// Try GetAppNameVersion to verify basic communication
	le.Printf("Verifying app name and version...")
	if err := tkey.GetAppNameVersion(); err != nil {
		le.Fatalf("Failed to verify app: %v", err)
	}


	// Convert challenge string to bytes
	challenge := []byte(challengeStr)
	le.Printf("Using challenge: %q (%d bytes)", challengeStr, len(challenge))

	// Set challenge size
	if err := tkey.SetChallenge(len(challenge)); err != nil {
		le.Fatalf("Failed to set challenge: %v", err)
	}

	// Load challenge data
	if err := tkey.LoadChallenge(challenge); err != nil {
		le.Fatalf("Failed to load challenge: %v", err)
	}

	// Derive key
	key, err := tkey.DeriveKey()
	if err != nil {
		le.Fatalf("Failed to derive key: %v", err)
	}

	if verbose {
		le.Printf("Derived key: %s", hex.EncodeToString(key))
	}

	// Output key if requested
	if outputPath != "" {
		if outputPath == "-" {
			// Write to stdout (for piping)
			if _, err := os.Stdout.Write(key); err != nil {
				le.Fatalf("Failed to write key to stdout: %v", err)
			}
		} else {
			// Write to file
			if err := os.WriteFile(outputPath, key, 0600); err != nil {
				le.Fatalf("Failed to write key to file: %v", err)
			}
			if verbose {
				le.Printf("Key written to: %s", outputPath)
			}
		}

		// If only outputting key, we're done
		if luksImage == "" && saveKeyPath == "" {
			return
		}
	}

	// Save key to file if requested (legacy/compatibility)
	if saveKeyPath != "" {
		if err := os.WriteFile(saveKeyPath, key, 0600); err != nil {
			le.Fatalf("Failed to save key: %v", err)
		}
		if verbose {
			le.Printf("Key saved to: %s", saveKeyPath)
		}

		if luksImage == "" {
			// Just saving key, we're done
			if verbose {
				le.Printf("Success!")
			}
			return
		}
	}

	// Unlock LUKS volume if image provided
	if luksImage != "" {
		// Create temporary key file
		tmpKey, err := os.CreateTemp("", "tkey-luks-*.key")
		if err != nil {
			le.Fatalf("Failed to create temp key file: %v", err)
		}
		defer os.Remove(tmpKey.Name())

		if _, err := tmpKey.Write(key); err != nil {
			le.Fatalf("Failed to write key to temp file: %v", err)
		}
		tmpKey.Close()

		le.Printf("Unlocking LUKS volume: %s", luksImage)
		if err := UnlockLUKS(tmpKey.Name(), luksImage, mapperName); err != nil {
			le.Fatalf("Failed to unlock LUKS: %v", err)
		}

		le.Printf("Success! Volume mounted at /dev/mapper/%s", mapperName)
	}
}

// Validate frame protocol and app-level protocol
func validateProtocol(rx []byte, expectedCmd byte) error {
	if len(rx) < 1 {
		return errors.New("empty response")
	}

	if rx[0] != expectedCmd {
		return fmt.Errorf("unexpected response code: 0x%02x (expected 0x%02x)", rx[0], expectedCmd)
	}

	return nil
}

// Helper to check if two byte slices are equal
func bytesEqual(a, b []byte) bool {
	return bytes.Equal(a, b)
}

// Helper to read file or stdin
func readInput(path string) ([]byte, error) {
	if path == "-" {
		return io.ReadAll(os.Stdin)
	}
	return os.ReadFile(path)
}
