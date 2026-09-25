#!/usr/bin/env bash
#
# Starts or stops the Docker Compose project for this repository on Linux
# (Debian/Ubuntu). Bash port of BuildTools/scripts/compose_project.ps1.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The compose file and env files live in BuildTools/ (two levels up from this script).
BUILD_TOOLS_DIR="$SCRIPT_DIR/../.."
DEFAULT_COMPOSE_FILE="$BUILD_TOOLS_DIR/docker-compose.yml"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Run docker, falling back to sudo when the user is not in the docker group
# (e.g. on VCL).
docker_run() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

usage() {
  echo ""
  echo "${CYAN}compose_project.sh - Start or stop the Docker Compose project on Linux${NC}"
  echo ""
  echo "Usage:"
  echo "    ./compose_project.sh (--start | --stop) [--build] [--compose-file <path>] [--remove-volumes] [--remove-images] [--help]"
  echo ""
  echo "What it does:"
  echo "    * --start -> runs 'docker compose up -d' (building images if needed) and prints the status."
  echo "      Add --build to force a rebuild of the image first."
  echo "    * --stop  -> runs 'docker compose down --remove-orphans' and, unless --remove-volumes /"
  echo "      --remove-images are passed, prompts about cleaning up volumes and images."
  echo "    * Exactly one of --start or --stop is required."
  echo ""
  echo "Options:"
  echo "    --start"
  echo "        Start the docker compose project and print the service status."
  echo "        Creates BuildTools/.env from example.env if it does not exist."
  echo ""
  echo "    --build"
  echo "        Force the image to be rebuilt when starting (adds --build to 'docker compose up')."
  echo "        By default, the image is built only if missing. Only used with --start."
  echo ""
  echo "    --stop"
  echo "        Stop and remove the docker compose project."
  echo ""
  echo "    --remove-volumes"
  echo "        Remove the named docker volumes defined by the compose file when stopping."
  echo ""
  echo "    --remove-images"
  echo "        Remove the docker images used by the compose project after stopping."
  echo "        NOTE: removing images forces a full rebuild the next time the project starts."
  echo ""
  echo "    --compose-file <path>"
  echo "        Path to the docker-compose file to manage."
  echo "        Default: $DEFAULT_COMPOSE_FILE"
  echo ""
  echo "    --help, -h"
  echo "        Show this help message and exit."
  echo ""
  echo "Examples:"
  echo "    ./compose_project.sh --start"
  echo "    ./compose_project.sh --start --build"
  echo "    ./compose_project.sh --stop"
  echo "    ./compose_project.sh --stop --remove-volumes --remove-images"
  echo "    ./compose_project.sh --start --compose-file /path/to/docker-compose.yml"
  echo "    ./compose_project.sh --help"
  echo ""
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
START=false
STOP=false
BUILD=false
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
COMPOSE_FILE="$DEFAULT_COMPOSE_FILE"

while [ $# -gt 0 ]; do
  case "$1" in
    --start)
      START=true
      ;;
    --stop)
      STOP=true
      ;;
    --build)
      BUILD=true
      ;;
    --remove-volumes)
      REMOVE_VOLUMES=true
      ;;
    --remove-images)
      REMOVE_IMAGES=true
      ;;
    --compose-file)
      if [ -z "${2:-}" ]; then
        echo "${RED}ERROR: --compose-file requires a path.${NC}" >&2
        exit 1
      fi
      COMPOSE_FILE="$2"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "${RED}ERROR: Unknown option: $1${NC}" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if $START && $STOP; then
  usage
  echo "${RED}Cannot specify both --stop and --start. Please choose one.${NC}" >&2
  exit 1
fi

if ! $START && ! $STOP; then
  usage
  echo "${RED}You must specify either --stop or --start. Please choose one.${NC}" >&2
  exit 1
fi

if $STOP && $BUILD; then
  echo "${YELLOW}NOTE: --build is ignored when stopping; it only applies to --start.${NC}"
fi

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
if $START; then
  # Create the .env file if it does not exist.
  if [ ! -f "$BUILD_TOOLS_DIR/.env" ] && [ -f "$BUILD_TOOLS_DIR/example.env" ]; then
    cp "$BUILD_TOOLS_DIR/example.env" "$BUILD_TOOLS_DIR/.env"
    echo "Created .env from example.env"
  fi

  echo "${CYAN}Starting the docker compose project...${NC}"
  if $BUILD; then
    docker_run compose -f "$COMPOSE_FILE" up -d --build
  else
    docker_run compose -f "$COMPOSE_FILE" up -d
  fi
  if [ $? -ne 0 ]; then
    echo "${RED}Failed to start the docker compose project. Please check the compose file and try again.${NC}" >&2
    exit 1
  fi
  docker_run compose -f "$COMPOSE_FILE" ps
  echo "${GREEN}Docker compose project started.${NC}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Stop
# ---------------------------------------------------------------------------
if ! $REMOVE_VOLUMES && ! $REMOVE_IMAGES; then
  echo "${YELLOW}NOTE: If you choose not to cleanup volumes, you will have to cleanup them manually later to avoid disk space issues.${NC}"
  read -r -p "Do you want to cleanup any associated docker volumes? (y|n) (default: n) " answer
  case "$answer" in
    [Yy]*) REMOVE_VOLUMES=true ;;
  esac

  echo "${YELLOW}NOTE: If you choose not to cleanup images, you will have to cleanup them manually later to avoid disk space issues.${NC}"
  echo "${YELLOW}      Do not clean them up if you're not finished with the project yet as that will cause a full rebuild.${NC}"
  read -r -p "Do you want to cleanup associated docker images? (y|n) (default: n) " answer
  case "$answer" in
    [Yy]*) REMOVE_IMAGES=true ;;
  esac
fi

if $REMOVE_IMAGES; then
  IMAGE_IDS="$(docker_run compose -f "$COMPOSE_FILE" images -q)"
fi

if [ -n "$(docker_run compose -f "$COMPOSE_FILE" ps -q)" ]; then
  if $REMOVE_VOLUMES; then
    docker_run compose -f "$COMPOSE_FILE" down --remove-orphans --volumes
  else
    docker_run compose -f "$COMPOSE_FILE" down --remove-orphans
  fi
  echo "${CYAN}Stopping and removing the docker compose project...${NC}"
  echo "${GREEN}Docker compose project stopped and removed.${NC}"
fi

if $REMOVE_IMAGES; then
  echo "${CYAN}Cleaning up docker images...${NC}"
  for image_id in $IMAGE_IDS; do
    echo "${YELLOW}Removing image: $image_id${NC}"
    docker_run rmi -f "$image_id"
  done
  echo "${GREEN}Docker images cleaned up.${NC}"
fi
