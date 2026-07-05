#!/bin/sh

NIKKI_REPOSITORY_URL="${NIKKI_REPOSITORY_URL:-https://nikkinikki.pages.dev}"
NIKKI_ARCH="${NIKKI_ARCH:-x86_64}"
NIKKI_LANG="${NIKKI_LANG:-zh-cn}"

nikki_package_list() {
  echo "ca-bundle curl yq ip-full kmod-inet-diag kmod-nft-socket kmod-nft-tproxy kmod-tun kmod-dummy mihomo-meta nikki luci-app-nikki luci-i18n-nikki-${NIKKI_LANG}"
}

nikki_package_version() {
  pkg_name="$1"
  index_file="$2"

  if command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then
    python3 - "$pkg_name" "$index_file" <<'PY'
import json
import sys

pkg_name = sys.argv[1]
index_file = sys.argv[2]

with open(index_file, "r", encoding="utf-8") as fh:
    data = json.load(fh)

print(data["packages"][pkg_name])
PY
  else
    sed -n "s/.*\"${pkg_name}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$index_file" | head -n 1
  fi
}

nikki_package_file_name() {
  pkg_name="$1"
  pkg_version="$2"
  package_type="$3"

  case "$package_type" in
    ipk)
      case "$pkg_name" in
        luci-app-nikki|luci-i18n-nikki-*)
          echo "${pkg_name}_${pkg_version}_all.ipk"
          ;;
        *)
          echo "${pkg_name}_${pkg_version}_${NIKKI_ARCH}.ipk"
          ;;
      esac
      ;;
    apk)
      echo "${pkg_name}-${pkg_version}.apk"
      ;;
    *)
      echo "unsupported Nikki package type: $package_type" >&2
      return 1
      ;;
  esac
}

nikki_download_packages() {
  branch="$1"
  package_type="$2"
  target_dir="${3:-/home/build/immortalwrt/packages}"
  feed_url="${NIKKI_REPOSITORY_URL}/${branch}/${NIKKI_ARCH}/nikki"
  index_file="/tmp/nikki-${branch}-${NIKKI_ARCH}-index.json"

  mkdir -p "$target_dir"
  echo "Downloading Nikki package index: ${feed_url}/index.json"
  if ! wget -q "${feed_url}/index.json" -O "$index_file"; then
    echo "Failed to download Nikki package index." >&2
    return 1
  fi

  for pkg_name in mihomo-meta nikki luci-app-nikki "luci-i18n-nikki-${NIKKI_LANG}"; do
    pkg_version="$(nikki_package_version "$pkg_name" "$index_file")"
    if [ -z "$pkg_version" ]; then
      echo "Failed to find Nikki package version for ${pkg_name}." >&2
      return 1
    fi

    pkg_file="$(nikki_package_file_name "$pkg_name" "$pkg_version" "$package_type")" || return 1
    echo "Downloading Nikki package: ${pkg_file}"
    if ! wget -q "${feed_url}/${pkg_file}" -P "$target_dir"; then
      echo "Failed to download Nikki package: ${pkg_file}" >&2
      return 1
    fi
  done
}
