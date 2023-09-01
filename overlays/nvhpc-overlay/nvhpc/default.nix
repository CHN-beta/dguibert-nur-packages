{
  url, version, sha256,
  lib, stdenv, fetchurl, nix-patchtools,
  more, zlib, ncurses, libxml2, glibc, file, gcc, flock, rdma-core
}:
stdenv.mkDerivation
{
  pname = "nvhpc";
  inherit version;
  src = fetchurl { inherit url sha256; };
  dontStrip = true;

  # manually patch it in installPhase
  dontPatchELF = true;
  buildInputs = [ nix-patchtools more zlib ncurses libxml2 glibc file gcc flock rdma-core ];
  installPhase =
  # ref to upstream install script
  ''
    mkdir -p $out
    mv install_components/Linux_x86_64/${version}/{comm_libs,compilers,cuda,examples,math_libs,profilers,REDIST} $out
    for i in libibverbs.so* librdmacm.so* libnl-3.so* libnl-route-3.so*; do
      rm $out/comm_libs/mpi/lib/$i
    done
    autoPatchelf $out
    $out/compilers/bin/makelocalrc -x $out/compilers/bin
    rm -f $out/compilers/glibc_version
    mkdir $out/bin
    ln -s $out/compilers/bin/* $out/bin/
  '';
  passthru =
  {
    isClang = false;
    langFortran = true;
    hardeningUnsupportedFlags = [ "fortify" "stackprotector" "pie" "pic" "strictoverflow" "format" ];
  };
}
