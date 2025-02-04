#!/bin/bash -e

# TODO: Review and if possible fix shellcheck errors.
# shellcheck disable=all

[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")/.." && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/tool_kit.sh
source "${SCRIPT_DIR}"/signal_trap.sh
source "${INSTALLDIR}"/toolchain.conf
source "${INSTALLDIR}"/toolchain.env

[ -f "${BUILDDIR}/setup_cmake" ] && rm "${BUILDDIR}/setup_cmake"

! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

case "${with_cmake}" in
  __INSTALL__)
    echo "==================== Installing CMake ===================="
    cmake_ver="3.28.1"
    if [ "${OPENBLAS_ARCH}" = "arm64" ]; then
      cmake_arch="linux-aarch64"
      cmake_sha256="4ecba78ef9499a973d012a83feab5f888e86fc5388e9a768037ab4f7232cab16"
    elif [ "${OPENBLAS_ARCH}" = "x86_64" ]; then
      cmake_arch="linux-x86_64"
      cmake_sha256="ada6a46be9da5f8cbeb00b9523ffe45ee6b36172eb81aaa5bdc6a2a8231b677c"
    else
      report_error ${LINENO} \
        "cmake installation for ARCH=${ARCH} is not supported. You can try to use the system installation using the flag --with-cmake=system instead."
      exit 1
    fi
    pkg_install_dir="${INSTALLDIR}/cmake-${cmake_ver}"
    install_lock_file="$pkg_install_dir/install_successful"
    if verify_checksums "${install_lock_file}"; then
      echo "cmake-${cmake_ver} is already installed, skipping it."
    else
      if [ -f cmake-${cmake_ver}-${cmake_arch}.sh ]; then
        echo "cmake-${cmake_ver}-${cmake_arch}.sh is found"
      else
        download_pkg_from_cp2k_org "${cmake_sha256}" "cmake-${cmake_ver}-${cmake_arch}.sh"
      fi
      echo "Installing from scratch into ${pkg_install_dir}"
      mkdir -p ${pkg_install_dir}
      /bin/sh cmake-${cmake_ver}-${cmake_arch}.sh --prefix=${pkg_install_dir} --skip-license > install.log 2>&1 || tail -n ${LOG_LINES} install.log
      write_checksums "${install_lock_file}" "${SCRIPT_DIR}/stage0/$(basename ${SCRIPT_NAME})"
    fi
    ;;
  __SYSTEM__)
    echo "==================== Finding CMake from system paths ===================="
    check_command cmake "cmake"
    ;;
  __DONTUSE__)
    # Nothing to do
    ;;
  *)
    echo "==================== Linking CMake to user paths ===================="
    pkg_install_dir="$with_cmake"
    check_dir "${with_cmake}/bin"
    ;;
esac
if [ "${with_cmake}" != "__DONTUSE__" ]; then
  if [ "${with_cmake}" != "__SYSTEM__" ]; then
    cat << EOF > "${BUILDDIR}/setup_cmake"
prepend_path PATH "${pkg_install_dir}/bin"
EOF
    cat "${BUILDDIR}/setup_cmake" >> $SETUPFILE
  fi
fi

load "${BUILDDIR}/setup_cmake"
write_toolchain_env "${INSTALLDIR}"

cd "${ROOTDIR}"
report_timing "cmake"
