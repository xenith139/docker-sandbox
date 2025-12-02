#!/bin/bash
# Run container script for tron-docker containers
# Usage: ./run-container.sh <identifier> [--description "text"]
# Example: ./run-container.sh 1  or  ./run-container.sh dev --description "Dev env"

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ===================================================================
# STEP 1: Parse arguments
# ===================================================================

IDENTIFIER=""
DESCRIPTION=""

# Parse all arguments
i=1
for arg in "$@"; do
    if [[ "$arg" == "--description" ]] || [[ "$arg" == "-d" ]]; then
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
    echo "Usage: ./run-container.sh <identifier> [--description \"text\"]"
    echo ""
    echo "Examples:"
    echo "  ./run-container.sh 1                        → Run/enter tron-docker-1"
    echo "  ./run-container.sh dev --description \"Dev\" → Non-interactive build if needed"
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

echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "=========================================="
echo ""

# ===================================================================
# STEP 3: Check if container and tracking file exist
# ===================================================================

CONTAINER_EXISTS=false
TRACKING_EXISTS=false

if docker ps -a -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
    CONTAINER_EXISTS=true
fi

if [ -f "$TRACKING_FILE" ]; then
    TRACKING_EXISTS=true
fi

# ===================================================================
# STEP 4: Handle missing container - build it
# ===================================================================

if [ "$CONTAINER_EXISTS" = false ] && [ "$TRACKING_EXISTS" = false ]; then
    # Check if image exists - if so, reuse it instead of rebuilding
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "Container '$CONTAINER_NAME' does not exist"
        echo "But image '$IMAGE_NAME' exists - reusing it"
        echo ""

        # Create tracking file for new container using existing image
        IMAGE_ID=$(docker images -q "$IMAGE_NAME" | head -1)

        # Get description if not provided
        if [ -z "$DESCRIPTION" ]; then
            echo "Please provide a description for this container."
            echo ""
            read -p "Description: " DESCRIPTION

            if [ -z "$DESCRIPTION" ]; then
                echo ""
                echo "❌ ERROR: Description cannot be empty"
                exit 1
            fi
        else
            echo "Using description: $DESCRIPTION"
        fi

        # Create tracking file
        cat > "$TRACKING_FILE" << EOF
Container Name: $CONTAINER_NAME
Image Name: $IMAGE_NAME
Image ID: $IMAGE_ID
Container ID: (not yet created)
Description: $DESCRIPTION
Created: $(date '+%Y-%m-%d %H:%M:%S')
Status: Reusing existing image, container not yet created
EOF

        echo "✅ Tracking file created (reusing existing image)"
        echo ""
    else
        echo "Container '$CONTAINER_NAME' does not exist"
        echo "Image and tracking file not found"
        echo ""
        echo "Building container using stop-rebuild.sh..."
        echo ""

        # Run stop-rebuild.sh to build the image
        # Pass description argument if provided
        if [ -n "$DESCRIPTION" ]; then
            bash "$SCRIPT_DIR/stop-rebuild.sh" "$IDENTIFIER" --description "$DESCRIPTION"
        else
            bash "$SCRIPT_DIR/stop-rebuild.sh" "$IDENTIFIER"
        fi

        # After build completes, check if image was created
        if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
            echo ""
            echo "❌ ERROR: Image build failed or was cancelled"
            exit 1
        fi

        echo ""
        echo "✅ Image built successfully!"
        echo ""
    fi
elif [ "$CONTAINER_EXISTS" = false ] && [ "$TRACKING_EXISTS" = true ]; then
    echo "⚠️  Warning: Tracking file exists but container doesn't"
    echo "Image exists but container was never created or was removed"
    echo ""
fi

# ===================================================================
# STEP 5: Create container if image exists but container doesn't
# ===================================================================

if [ "$CONTAINER_EXISTS" = false ]; then
    # Image should exist at this point (from build or tracking file)
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "❌ ERROR: Image '$IMAGE_NAME' not found"
        echo "Run: ./stop-rebuild.sh $IDENTIFIER"
        exit 1
    fi

    echo "Creating container: $CONTAINER_NAME"
    echo "From image: $IMAGE_NAME"
    echo ""

    # Create container with sleep infinity to keep it running
    docker run -d \
        --name "$CONTAINER_NAME" \
        --gpus all \
        -e TERM="${TERM:-xterm-256color}" \
        "$IMAGE_NAME"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to create container"
        exit 1
    fi

    echo "✅ Container created successfully!"

    # Update tracking file with container ID
    if [ -f "$TRACKING_FILE" ]; then
        CONTAINER_ID=$(docker ps -a -q -f name="^${CONTAINER_NAME}$")

        # Update the Container ID line in tracking file
        sed -i "s/Container ID: .*/Container ID: $CONTAINER_ID/" "$TRACKING_FILE"
        sed -i "s/Status: .*/Status: Container created and running/" "$TRACKING_FILE"

        echo "✅ Tracking file updated with container ID"
    fi

    echo ""
fi

# ===================================================================
# STEP 6: Check if container is running, start if stopped
# ===================================================================

if ! docker ps -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
    echo "Container exists but is stopped"
    echo "Starting container: $CONTAINER_NAME"
    echo ""

    docker start "$CONTAINER_NAME"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to start container"
        exit 1
    fi

    echo "✅ Container started successfully!"
    echo ""
fi

# ===================================================================
# STEP 7: Enter container with bash
# ===================================================================

echo "🐚 Entering bash session in container..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Container: $CONTAINER_NAME"
echo "User: ubuntu"
echo "Working directory: /home/ubuntu"
echo ""
echo "To exit container: type 'exit' or press Ctrl+D"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Execute bash in container as ubuntu user
docker exec -it -u ubuntu -w /home/ubuntu "$CONTAINER_NAME" /bin/bash

# ===================================================================
# STEP 8: Post-exit message
# ===================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Exited from container: $CONTAINER_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Container is still running in background"
echo ""
echo "To re-enter: ./run-container.sh $IDENTIFIER"
echo "To stop: docker stop $CONTAINER_NAME"
echo "To rebuild: ./stop-rebuild.sh $IDENTIFIER"
echo ""
