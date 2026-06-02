#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_PLATFORM_DIR="${NATIVE_PLATFORM_DIR:-$ROOT_DIR/native-platform}"
NATIVE_PLATFORM_VERSION="${NATIVE_PLATFORM_VERSION:-0.22-milestone-28-custom}"
NATIVE_PLATFORM_REPO="${NATIVE_PLATFORM_REPO:-$NATIVE_PLATFORM_DIR/build/repo}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "native-platform macOS artifact must be built on macOS." >&2
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "native-platform osx-amd64 artifact must be built on an x86_64 macOS runner." >&2
  exit 1
fi

if [[ ! -d "$NATIVE_PLATFORM_DIR" ]]; then
  echo "Missing native-platform checkout: $NATIVE_PLATFORM_DIR" >&2
  exit 1
fi

if [[ "$NATIVE_PLATFORM_VERSION" =~ ^([0-9]+(\.[0-9]+)+) ]]; then
  NATIVE_PLATFORM_BASE_VERSION="${BASH_REMATCH[1]}"
else
  echo "NATIVE_PLATFORM_VERSION must start with a numeric base version, for example 0.22-dev or 0.22-milestone-28-custom." >&2
  exit 1
fi

NATIVE_PLATFORM_BUILD_VERSION="${NATIVE_PLATFORM_BASE_VERSION}-dev"

echo "Building native-platform $NATIVE_PLATFORM_BUILD_VERSION for osx-amd64"
echo "Publishing local Maven coordinates as $NATIVE_PLATFORM_VERSION"
echo "Using JAVA_HOME=${JAVA_HOME:-not set}"
java -version
xcode-select -p
clang --version

cd "$NATIVE_PLATFORM_DIR"

./gradlew \
  --no-daemon \
  --stacktrace \
  clean \
  :native-platform:publishAllPublicationsToLocalFileRepository \
  -PonlyLocalVariants \
  "-PnextVersion=$NATIVE_PLATFORM_BASE_VERSION"

copy_artifact_version() {
  local artifact_id="$1"
  local source_dir="$NATIVE_PLATFORM_REPO/net/rubygrapefruit/$artifact_id/$NATIVE_PLATFORM_BUILD_VERSION"
  local target_dir="$NATIVE_PLATFORM_REPO/net/rubygrapefruit/$artifact_id/$NATIVE_PLATFORM_VERSION"

  if [[ "$NATIVE_PLATFORM_VERSION" == "$NATIVE_PLATFORM_BUILD_VERSION" ]]; then
    return
  fi

  if [[ ! -d "$source_dir" ]]; then
    echo "Expected published artifact directory does not exist: $source_dir" >&2
    exit 1
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  for source_file in "$source_dir"/"$artifact_id-$NATIVE_PLATFORM_BUILD_VERSION"*; do
    local file_name
    file_name="$(basename "$source_file")"
    local target_file="$target_dir/${file_name/$NATIVE_PLATFORM_BUILD_VERSION/$NATIVE_PLATFORM_VERSION}"
    cp "$source_file" "$target_file"
    if [[ "$target_file" == *.pom || "$target_file" == *.module ]]; then
      NATIVE_PLATFORM_BUILD_VERSION="$NATIVE_PLATFORM_BUILD_VERSION" \
        NATIVE_PLATFORM_VERSION="$NATIVE_PLATFORM_VERSION" \
        perl -0pi -e 's/\Q$ENV{NATIVE_PLATFORM_BUILD_VERSION}\E/$ENV{NATIVE_PLATFORM_VERSION}/g' "$target_file"
    fi
  done
}

copy_artifact_version native-platform
copy_artifact_version native-platform-osx-amd64

required_artifacts=(
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform/$NATIVE_PLATFORM_VERSION/native-platform-$NATIVE_PLATFORM_VERSION.jar"
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform/$NATIVE_PLATFORM_VERSION/native-platform-$NATIVE_PLATFORM_VERSION.pom"
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform-osx-amd64/$NATIVE_PLATFORM_VERSION/native-platform-osx-amd64-$NATIVE_PLATFORM_VERSION.jar"
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform-osx-amd64/$NATIVE_PLATFORM_VERSION/native-platform-osx-amd64-$NATIVE_PLATFORM_VERSION.pom"
)

for artifact in "${required_artifacts[@]}"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Expected artifact was not published: $artifact" >&2
    echo "Published files:" >&2
    find "$NATIVE_PLATFORM_REPO" -type f | sort >&2 || true
    exit 1
  fi
done

echo "native-platform Maven repository:"
find "$NATIVE_PLATFORM_REPO/net/rubygrapefruit" -type f | sort
