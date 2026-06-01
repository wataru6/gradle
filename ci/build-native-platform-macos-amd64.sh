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

version_args=()
if [[ "$NATIVE_PLATFORM_VERSION" =~ ^([0-9]+(\.[0-9]+)+)-milestone-([0-9]+)$ ]]; then
  version_args+=("-Pmilestone")
  version_args+=("-PnextVersion=${BASH_REMATCH[1]}")
  version_args+=("-PnextMilestone=${BASH_REMATCH[3]}")
elif [[ "$NATIVE_PLATFORM_VERSION" =~ ^([0-9]+(\.[0-9]+)+)-dev$ ]]; then
  version_args+=("-PnextVersion=${BASH_REMATCH[1]}")
elif [[ "$NATIVE_PLATFORM_VERSION" =~ ^([0-9]+(\.[0-9]+)+)-(.+)$ ]]; then
  version_args+=("-Palpha=${BASH_REMATCH[3]}")
  version_args+=("-PnextVersion=${BASH_REMATCH[1]}")
else
  version_args+=("-Prelease")
  version_args+=("-PnextVersion=$NATIVE_PLATFORM_VERSION")
fi

echo "Building native-platform $NATIVE_PLATFORM_VERSION for osx-amd64"
echo "Using JAVA_HOME=${JAVA_HOME:-not set}"
java -version
xcode-select -p
clang --version

cd "$NATIVE_PLATFORM_DIR"

./gradlew \
  --no-daemon \
  --stacktrace \
  clean \
  :native-platform:build \
  :native-platform:publishAllPublicationsToLocalFileRepository \
  -PonlyLocalVariants \
  "${version_args[@]}"

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
