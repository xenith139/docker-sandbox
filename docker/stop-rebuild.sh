#!/bin/bash
# Stop and rebuild script for tron-docker containers
# Usage: ./stop-rebuild.sh <identifier> [--delete] [--prompt-override-allow] [--description "text"]
# Example: ./stop-rebuild.sh 1  or  ./stop-rebuild.sh dev --prompt-override-allow --description "Dev container"
#          ./stop-rebuild.sh 1 --delete  (delete only, no rebuild)
#          ./stop-rebuild.sh 1 --delete --prompt-override-allow  (delete without confirmation)

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ===================================================================
# STEP 1: Parse arguments
# ===================================================================

IDENTIFIER=""
PROMPT_OVERRIDE_ALLOW=false
DELETE_ONLY=false
DESCRIPTION=""

# Parse all arguments
i=1
for arg in "$@"; do
    if [[ "$arg" == "--prompt-override-allow" ]]; then
        PROMPT_OVERRIDE_ALLOW=true
    elif [[ "$arg" == "--delete" ]]; then
        DELETE_ONLY=true
    elif [[ "$arg" == "--description" ]] || [[ "$arg" == "-d" ]]; then
        # Next argument should be the description
        i=$((i + 1))
        eval "DESCRIPTION=\${$i}"
        if [ -z "$DESCRIPTION" ]; then
            echo "❌ ERROR: --description requires a value"
            exit 1
        fi
    elif [[ "$arg" == --description=* ]]; then
        # Handle --description="value" format
        DESCRIPTION="${arg#--description=}"
    elif [[ "$arg" != "$DESCRIPTION" ]]; then
        # Only set identifier if this isn't the description value we just parsed
        if [ -z "$IDENTIFIER" ]; then
            IDENTIFIER="$arg"
        fi
    fi
    i=$((i + 1))
done

# Check if identifier provided
if [ -z "$IDENTIFIER" ]; then
    echo "❌ ERROR: Container identifier required"
    echo ""
    echo "Usage: ./stop-rebuild.sh <identifier> [--delete] [--prompt-override-allow] [--description \"text\"]"
    echo ""
    echo "Options:"
    echo "  --delete                  Delete container/image only (no rebuild)"
    echo "  --prompt-override-allow   Skip confirmation prompt (use with caution)"
    echo "  --description \"text\"      Container description for tracking file"
    echo ""
    echo "Examples:"
    echo "  ./stop-rebuild.sh 1                                          → Rebuild tron-docker-1 (interactive)"
    echo "  ./stop-rebuild.sh dev --prompt-override-allow                → Rebuild without confirmation"
    echo "  ./stop-rebuild.sh 1 --description \"test\"                     → Non-interactive with description"
    echo "  ./stop-rebuild.sh 1 --delete                                 → Delete only (with confirmation)"
    echo "  ./stop-rebuild.sh 1 --delete --prompt-override-allow         → Delete only (no confirmation)"
    echo ""
    exit 1
fi

# Validate identifier (allow alphanumeric and dashes, no spaces)
if [[ ! "$IDENTIFIER" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "❌ ERROR: Invalid identifier '$IDENTIFIER'"
    echo ""
    echo "Identifier must contain only:"
    echo "  • Letters (a-z, A-Z)"
    echo "  • Numbers (0-9)"
    echo "  • Dashes (-)"
    echo "  • No spaces or special characters"
    echo ""
    exit 1
fi

# ===================================================================
# STEP 2: Set names and paths
# ===================================================================

CONTAINER_NAME="tron-docker-$IDENTIFIER"
IMAGE_NAME="tron-docker"
TRACKING_FILE="$SCRIPT_DIR/tron-docker-$IDENTIFIER.txt"

# ===================================================================
# STEP 3: Check if container/image/tracking file exists
# ===================================================================

CONTAINER_EXISTS=false
IMAGE_EXISTS=false
TRACKING_EXISTS=false

if docker ps -a -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
    CONTAINER_EXISTS=true
fi

if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    IMAGE_EXISTS=true
fi

if [ -f "$TRACKING_FILE" ]; then
    TRACKING_EXISTS=true
fi

# If nothing exists, this is a fresh build (not a rebuild)
if [ "$CONTAINER_EXISTS" = false ] && [ "$IMAGE_EXISTS" = false ] && [ "$TRACKING_EXISTS" = false ]; then
    echo "=========================================="
    echo "Fresh Build: $CONTAINER_NAME"
    echo "=========================================="
    echo ""
    echo "No existing container, image, or tracking file found."
    echo "Proceeding with fresh build..."
    echo ""
    # Skip to build section
    SKIP_CLEANUP=true
else
    SKIP_CLEANUP=false
fi

# ===================================================================
# STEP 4: Warn about destructive operation and get confirmation
# ===================================================================

if [ "$SKIP_CLEANUP" = false ]; then
    echo "=========================================================================================================="
    echo "⚠️  WARNING: DESTRUCTIVE OPERATION"
    echo "=========================================================================================================="
    echo ""
    if [ "$DELETE_ONLY" = true ]; then
        echo "This will PERMANENTLY DELETE the following for '$CONTAINER_NAME' (DELETE ONLY - NO REBUILD):"
    else
        echo "This will PERMANENTLY DELETE the following for '$CONTAINER_NAME':"
    fi
    echo ""

    if [ "$CONTAINER_EXISTS" = true ]; then
        echo "  ✗ Container: $CONTAINER_NAME"
        echo "      - All files and data inside the container"
        echo "      - All installed packages"
        echo "      - All work in /home/ubuntu"
    fi

    if [ "$IMAGE_EXISTS" = true ]; then
        echo "  ✗ Image: $IMAGE_NAME"
    fi

    if [ "$TRACKING_EXISTS" = true ]; then
        echo "  ✗ Tracking file: $TRACKING_FILE"
    fi

    echo ""
    echo "This action CANNOT be undone!"
    echo ""

    # Check if --prompt-override-allow flag was provided
    if [ "$PROMPT_OVERRIDE_ALLOW" = true ]; then
        echo "🔥 --prompt-override-allow flag detected, skipping confirmation..."
        echo ""
    else
        # Ask for confirmation
        if [ "$DELETE_ONLY" = true ]; then
            echo "To proceed with DELETE, type 'yes' (lowercase, exactly):"
        else
            echo "To proceed with rebuild, type 'yes' (lowercase, exactly):"
        fi
        read -p "> " CONFIRMATION

        if [ "$CONFIRMATION" != "yes" ]; then
            echo ""
            if [ "$DELETE_ONLY" = true ]; then
                echo "❌ Delete cancelled (you typed: '$CONFIRMATION')"
            else
                echo "❌ Rebuild cancelled (you typed: '$CONFIRMATION')"
            fi
            echo ""
            echo "To proceed without confirmation, use:"
            echo "  ./stop-rebuild.sh $IDENTIFIER --prompt-override-allow"
            echo ""
            exit 1
        fi

        echo ""
        if [ "$DELETE_ONLY" = true ]; then
            echo "✅ Confirmation received, proceeding with delete..."
        else
            echo "✅ Confirmation received, proceeding with rebuild..."
        fi
        echo ""
    fi

    # ===================================================================
    # STEP 5: Delete existing container, image, and tracking file
    # ===================================================================

    echo "=========================================="
    echo "Cleaning Up Existing Resources"
    echo "=========================================="
    echo ""

    # Stop and remove container if exists
    if [ "$CONTAINER_EXISTS" = true ]; then
        echo "🗑️  Removing container: $CONTAINER_NAME"
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
        echo "   ✓ Container removed"
    fi

    # Remove image if exists
    if [ "$IMAGE_EXISTS" = true ]; then
        echo "🗑️  Removing image: $IMAGE_NAME"
        docker rmi -f "$IMAGE_NAME" >/dev/null 2>&1 || true
        echo "   ✓ Image removed"
    fi

    # Remove tracking file if exists
    if [ "$TRACKING_EXISTS" = true ]; then
        echo "🗑️  Removing tracking file: $TRACKING_FILE"
        rm -f "$TRACKING_FILE"
        echo "   ✓ Tracking file removed"
    fi

    echo ""
    echo "✅ Cleanup complete!"
    echo ""

    # If delete-only mode, exit here without rebuilding
    if [ "$DELETE_ONLY" = true ]; then
        echo "=========================================="
        echo "✅ Delete Complete!"
        echo "=========================================="
        echo ""
        echo "Container '$CONTAINER_NAME' and associated resources have been deleted."
        echo "No rebuild was performed (--delete mode)."
        echo ""
        exit 0
    fi
fi

# If delete-only but nothing existed to delete
if [ "$DELETE_ONLY" = true ] && [ "$SKIP_CLEANUP" = true ]; then
    echo "=========================================="
    echo "ℹ️  Nothing to Delete"
    echo "=========================================="
    echo ""
    echo "No container, image, or tracking file found for '$CONTAINER_NAME'."
    echo "Nothing was deleted."
    echo ""
    exit 0
fi

# ===================================================================
# STEP 6: Get container description
# ===================================================================

echo "=========================================="
echo "Building: $CONTAINER_NAME"
echo "=========================================="
echo ""

# Check if description was provided via argument
if [ -z "$DESCRIPTION" ]; then
    echo "Please provide a description for this container."
    echo "This will be saved in the tracking file for reference."
    echo ""
    read -p "Description: " DESCRIPTION

    # Validate description is not empty
    if [ -z "$DESCRIPTION" ]; then
        echo ""
        echo "❌ ERROR: Description cannot be empty"
        exit 1
    fi
else
    echo "Using description from argument: $DESCRIPTION"
fi

echo ""

# ===================================================================
# STEP 7: Build Docker image
# ===================================================================

echo ""
echo "=========================================="
echo "Building Docker Image"
echo "=========================================="
echo "Image: $IMAGE_NAME"
echo "Context: $SCRIPT_DIR"
echo ""

# Build with progress
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Image build failed"
    exit 1
fi

# ===================================================================
# STEP 8: Get image details and create tracking file
# ===================================================================

# Get image ID
IMAGE_ID=$(docker images -q "$IMAGE_NAME" | head -1)

# Create tracking file
echo ""
echo "Creating tracking file..."

cat > "$TRACKING_FILE" << EOF
Container Name: $CONTAINER_NAME
Image Name: $IMAGE_NAME
Image ID: $IMAGE_ID
Container ID: (not yet created)
Description: $DESCRIPTION
Created: $(date '+%Y-%m-%d %H:%M:%S')
Status: Image built, container not yet created
EOF

# ===================================================================
# STEP 9: Success summary
# ===================================================================

echo ""
echo "=========================================="
echo "✅ Build Complete!"
echo "=========================================="
echo ""
echo "Container Details:"
echo "  Name:        $CONTAINER_NAME"
echo "  Image:       $IMAGE_NAME"
echo "  Image ID:    $IMAGE_ID"
echo "  Description: $DESCRIPTION"
echo ""
echo "Tracking file: $TRACKING_FILE"
echo ""
echo "Next Steps:"
echo "  • The image is ready but container not yet created"
echo "  • To create and run the container:"
echo "      docker run -d --name $CONTAINER_NAME $IMAGE_NAME"
echo "  • To enter with bash:"
echo "      docker exec -it -u ubuntu $CONTAINER_NAME bash"
echo ""
