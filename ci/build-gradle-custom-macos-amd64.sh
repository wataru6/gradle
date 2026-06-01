#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_DIR="${GRADLE_DIR:-$ROOT_DIR/gradle}"
NATIVE_PLATFORM_VERSION="${NATIVE_PLATFORM_VERSION:-0.22-milestone-28-custom}"
NATIVE_PLATFORM_REPO="${NATIVE_PLATFORM_REPO:-$ROOT_DIR/native-platform/build/repo}"
GRADLE_VERSION_QUALIFIER="${GRADLE_VERSION_QUALIFIER:-custom}"
INIT_SCRIPT="$ROOT_DIR/ci/custom-native-platform.init.gradle"
VERSION_FILE="$GRADLE_DIR/packaging/distributions-dependencies/build.gradle.kts"

if [[ ! -d "$GRADLE_DIR" ]]; then
  echo "Missing Gradle checkout: $GRADLE_DIR" >&2
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Cannot find Gradle native-platform version file: $VERSION_FILE" >&2
  exit 1
fi

if [[ ! -f "$INIT_SCRIPT" ]]; then
  echo "Cannot find init script: $INIT_SCRIPT" >&2
  exit 1
fi

required_artifacts=(
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform/$NATIVE_PLATFORM_VERSION/native-platform-$NATIVE_PLATFORM_VERSION.jar"
  "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/native-platform-osx-amd64/$NATIVE_PLATFORM_VERSION/native-platform-osx-amd64-$NATIVE_PLATFORM_VERSION.jar"
)

for artifact in "${required_artifacts[@]}"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Missing custom native-platform artifact: $artifact" >&2
    exit 1
  fi
done

version_file_backup="$(mktemp)"
cp "$VERSION_FILE" "$version_file_backup"
cleanup() {
  cp "$version_file_backup" "$VERSION_FILE"
  rm -f "$version_file_backup"
}
trap cleanup EXIT

echo "Patching Gradle nativePlatformVersion to $NATIVE_PLATFORM_VERSION for this build"
NATIVE_PLATFORM_VERSION="$NATIVE_PLATFORM_VERSION" perl -0pi -e 's/val nativePlatformVersion = "[^"]+"/val nativePlatformVersion = "$ENV{NATIVE_PLATFORM_VERSION}"/' "$VERSION_FILE"

if ! grep -nF "val nativePlatformVersion = \"$NATIVE_PLATFORM_VERSION\"" "$VERSION_FILE"; then
  echo "Failed to patch nativePlatformVersion in $VERSION_FILE" >&2
  exit 1
fi

echo "Building Gradle distribution with custom native-platform from $NATIVE_PLATFORM_REPO"
echo "Using JAVA_HOME=${JAVA_HOME:-not set}"
java -version

cd "$GRADLE_DIR"

gradle_version_args=()
if [[ -n "$GRADLE_VERSION_QUALIFIER" ]]; then
  gradle_version_args+=("-PversionQualifier=$GRADLE_VERSION_QUALIFIER")
fi

NATIVE_PLATFORM_REPO="$NATIVE_PLATFORM_REPO" ./gradlew \
  --no-daemon \
  --stacktrace \
  --dependency-verification off \
  --init-script "$INIT_SCRIPT" \
  "${gradle_version_args[@]}" \
  :distributions-full:binDistributionZip

distribution_zip="$(find "$GRADLE_DIR/packaging/distributions-full/build/distributions" -name 'gradle-*-bin.zip' -type f -print -quit)"

if [[ -z "$distribution_zip" ]]; then
  echo "Gradle distribution zip was not produced." >&2
  exit 1
fi

echo "Built Gradle distribution: $distribution_zip"

if ! unzip -l "$distribution_zip" | grep -F "native-platform-$NATIVE_PLATFORM_VERSION.jar"; then
  echo "Distribution does not contain native-platform-$NATIVE_PLATFORM_VERSION.jar" >&2
  exit 1
fi

if ! unzip -l "$distribution_zip" | grep -F "native-platform-osx-amd64-$NATIVE_PLATFORM_VERSION.jar"; then
  echo "Distribution does not contain native-platform-osx-amd64-$NATIVE_PLATFORM_VERSION.jar" >&2
  exit 1
fi
