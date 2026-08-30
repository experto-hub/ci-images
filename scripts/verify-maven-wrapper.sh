#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <image> <expected-java-feature>" >&2
  exit 2
fi

image="$1"
expected_java_feature="$2"

docker run --rm \
  --env "EXPECTED_JAVA_FEATURE=${expected_java_feature}" \
  "$image" \
  sh -ceu '
    wrapper_version="3.3.4"
    wrapper_archive_sha256="6cb584c2bc907b849a0b931d8266d3ff3214cdd3127115ed4f49fb7176413d36"
    maven_version="3.9.16"
    maven_distribution_sha256="5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce"
    smoke_dir="$(mktemp -d)"
    trap '\''rm -rf "$smoke_dir"'\'' EXIT

    wrapper_archive="${smoke_dir}/maven-wrapper.zip"
    curl --fail --silent --show-error --location \
      --output "$wrapper_archive" \
      "https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper-distribution/${wrapper_version}/maven-wrapper-distribution-${wrapper_version}-only-script.zip"
    printf "%s  %s\n" "$wrapper_archive_sha256" "$wrapper_archive" | sha256sum --check --strict -
    unzip -q "$wrapper_archive" -d "$smoke_dir/project"

    cd "$smoke_dir/project"
    mkdir -p .mvn/wrapper
    cat > .mvn/wrapper/maven-wrapper.properties <<EOF
distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${maven_version}/apache-maven-${maven_version}-bin.zip
distributionSha256Sum=${maven_distribution_sha256}
EOF
    cat > pom.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.github.experto-hub.ci</groupId>
  <artifactId>maven-wrapper-smoke</artifactId>
  <version>1.0.0</version>
</project>
EOF
    chmod +x mvnw

    wrapper_output="$(MAVEN_USER_HOME="$smoke_dir/m2" ./mvnw --version)"
    printf "%s\n" "$wrapper_output"
    printf "%s\n" "$wrapper_output" | grep -F "Apache Maven ${maven_version}"
    printf "%s\n" "$wrapper_output" | grep -E "Java version: ${EXPECTED_JAVA_FEATURE}([.,]|$)"
    MAVEN_USER_HOME="$smoke_dir/m2" ./mvnw --batch-mode --no-transfer-progress validate
    ! command -v mvn
  '

echo "maven_wrapper=passed image=${image} java_feature=${expected_java_feature}"
