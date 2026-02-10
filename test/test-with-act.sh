#!/bin/bash
# Test GitHub Actions workflow locally using 'act'
# https://github.com/nektos/act

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Testing GitHub Actions Workflow with 'act' ==="
echo ""

# Check if act is installed
ACT_CMD="$PROJECT_ROOT/bin/act"
if [ ! -x "$ACT_CMD" ]; then
    # Fall back to system act
    if command -v act &> /dev/null; then
        ACT_CMD="act"
    else
        echo "ERROR: 'act' is not installed"
        echo ""
        echo "Install act:"
        echo "  Ubuntu/Debian: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
        echo "  macOS: brew install act"
        echo "  Or download from: https://github.com/nektos/act/releases"
        echo "  Or to local bin: mkdir -p bin && curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar xz -C bin"
        echo ""
        exit 1
    fi
fi

echo "Using act: $ACT_CMD"
"$ACT_CMD" --version
echo ""

# Parse arguments
JOB="build-and-package"
EVENT="workflow_dispatch"
VERSION="1.1.0"

while [[ $# -gt 0 ]]; do
    case $1 in
        --job)
            JOB="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --list)
            echo "Available jobs in release.yml:"
            "$ACT_CMD" -l -W .github/workflows/release.yml
            exit 0
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --job JOB         Job to test (default: build-and-package)
  --version VER     Version to build (default: 1.1.0)
  --list            List available jobs and exit
  --help            Show this help message

Examples:
  $0                                    # Test build-and-package job
  $0 --job test-package                # Test installation job
  $0 --version 1.2.0                   # Test with specific version
  $0 --list                            # List all jobs

Note: act runs workflows in Docker containers and closely simulates GitHub Actions.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create input file for workflow_dispatch event
echo "Testing job: $JOB"
echo "Version: $VERSION"
echo ""

# Run act
echo "Running workflow with act (this may take a while)..."
echo "Press Ctrl+C to cancel"
echo ""

if [ "$JOB" = "build-and-package" ]; then
    "$ACT_CMD" workflow_dispatch \
        -W .github/workflows/release.yml \
        -j "$JOB" \
        --input version="$VERSION" \
        --container-architecture linux/amd64 \
        --bind \
        -P ubuntu-24.04=catthehacker/ubuntu:full-24.04 \
        -v
elif [ "$JOB" = "test-package" ]; then
    echo "WARNING: test-package job requires artifacts from build-and-package"
    echo "Running both jobs in sequence..."
    "$ACT_CMD" workflow_dispatch \
        -W .github/workflows/release.yml \
        --input version="$VERSION" \
        --container-architecture linux/amd64 \
        --bind \
        -P ubuntu-24.04=catthehacker/ubuntu:full-24.04 \
        -v
else
    "$ACT_CMD" workflow_dispatch \
        -W .github/workflows/release.yml \
        -j "$JOB" \
        --input version="$VERSION" \
        --container-architecture linux/amd64 \
        --bind \
        -P ubuntu-24.04=catthehacker/ubuntu:full-24.04 \
        -v
fi

echo ""
echo "✅ Workflow test completed!"
echo ""
echo "Notes:"
echo "  - act uses Docker to simulate GitHub Actions runners"
echo "  - Artifacts are saved to /tmp/act-* directories"
echo "  - Some features may behave differently than on GitHub"
