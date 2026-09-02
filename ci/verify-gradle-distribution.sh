#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_DIR="${GRADLE_DIR:-$ROOT_DIR/gradle}"
NATIVE_PLATFORM_VERSION="${NATIVE_PLATFORM_VERSION:-0.22-milestone-29-custom}"
NATIVE_PLATFORM_REPO="${NATIVE_PLATFORM_REPO:-$ROOT_DIR/native-platform/build/repo}"
GRADLE_VERSION="$(cat "$GRADLE_DIR/version.txt")"
distribution_zip="$GRADLE_DIR/packaging/distributions-full/build/distributions/gradle-$GRADLE_VERSION-bin.zip"

verification_dir="$(mktemp -d)"
trap 'rm -rf "$verification_dir"' EXIT
unzip -q "$distribution_zip" -d "$verification_dir"
distribution_dir="$verification_dir/gradle-$GRADLE_VERSION"

# Check the actual bytes, so an official or stale JAR cannot pass by name alone.
for artifact_id in native-platform native-platform-osx-amd64; do
  artifact_name="$artifact_id-$NATIVE_PLATFORM_VERSION.jar"
  cmp "$NATIVE_PLATFORM_REPO/net/rubygrapefruit/$artifact_id/$NATIVE_PLATFORM_VERSION/$artifact_name" \
    "$distribution_dir/lib/$artifact_name"
done

"$distribution_dir/bin/gradle" --version | tee "$verification_dir/version.txt"
grep -Fx "Gradle $GRADLE_VERSION" "$verification_dir/version.txt"

mkdir "$verification_dir/project"
printf "rootProject.name = 'custom-gradle-smoke-test'\n" > "$verification_dir/project/settings.gradle"
"$distribution_dir/bin/gradle" --no-daemon --console plain \
  --gradle-user-home "$verification_dir/gradle-user-home" \
  --project-dir "$verification_dir/project" help

shasum -a 256 "$distribution_zip" | awk '{print $1}' > "$distribution_zip.sha256"
echo "Verified Gradle $GRADLE_VERSION with native-platform $NATIVE_PLATFORM_VERSION"
