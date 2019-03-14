{ stdenv, fetchurl, glibc, file
, patchelf
, version ? "2019.0.117"
, preinstDir ? "compilers_and_libraries_${version}/linux"
}:

let
redist_srcs = {
  #https://software.intel.com/en-us/articles/redistributable-libraries-for-intel-c-and-fortran-2019-compilers-for-linux
  "2019.1.144" = fetchurl { url="https://software.intel.com/sites/default/files/managed/79/cd/l_comp_lib_2019.1.144_comp.for_redist.tgz"; sha256="05kd2lc2iyq3rgnbcalri86nf615n0c1ii21152yrfyxyhk60dxm"; };
  #"2019.2.187" = fetchurl { url="https://software.intel.com/sites/default/files/managed/2f/24/l_comp_lib_2019.2.187_comp.cpp_redist.tgz"; sha256=""; };
  "2019.2.187" = fetchurl { url="https://software.intel.com/sites/default/files/managed/95/e7/l_comp_lib_2019.2.187_comp.for_redist.tgz"; sha256="0sj0plax2bnid1qm1jqvijiflzfvs37vkfmg93mb7202g9fp7q77"; };
  "2019.3.199" = fetchurl { url="https://software.intel.com/sites/default/files/managed/7f/23/l_comp_lib_2019.3.199_comp.for_redist.tgz"; sha256="06c3w65ir481bqnwbmd9nqigrhcb3qyxbmx2ympckygjiparwh05"; };
};

in stdenv.mkDerivation rec {
  inherit version;
  name = "intel-compilers-redist-${version}";

  src = redist_srcs."${version}";
  nativeBuildInputs= [ file patchelf ];

  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    set -xv
    mkdir $out
    mv compilers_and_libraries_${version}/linux/* $out
    ln -s $out/compiler/lib/intel64_lin $out/lib
    set +xv
  '';
  preFixup = ''
    echo "Patching rpath and interpreter..."
    for f in $(find $out -type f -executable); do
      type="$(file -b --mime-type $f)"
      case "$type" in
      "application/executable"|"application/x-executable")
        echo "Patching executable: $f"
        patchelf --set-interpreter $(echo ${glibc}/lib/ld-linux*.so.2) --set-rpath ${glibc}/lib:\$ORIGIN:\$ORIGIN/../lib $f || true
        ;;
      "application/x-sharedlib"|"application/x-pie-executable")
        echo "Patching library: $f"
        patchelf --set-rpath ${glibc}/lib:\$ORIGIN:\$ORIGIN/../lib $f || true
        ;;
      *)
        echo "$f ($type) not patched"
        ;;
      esac
    done

    echo "Fixing path into scripts..."
    for file in `grep -l -r "${preinstDir}/" $out`
    do
      sed -e "s,${preinstDir}/,$out,g" -i $file
    done
  '';

  meta = {
    description = "Intel compilers and libraries ${version}";
    maintainers = [ stdenv.lib.maintainers.dguibert ];
    platforms = stdenv.lib.platforms.linux;
  };

}
