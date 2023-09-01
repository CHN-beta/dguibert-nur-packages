{
  url, version, sha256,
  lib, stdenv, fetchurl, autoPatchelfHook,
  zlib, libxml2, glibc, rdma-core, cudaPackages, flock
}:
stdenv.mkDerivation
{
  pname = "nvhpc";
  inherit version;
  src = fetchurl { inherit url sha256; };
  dontStrip = true;

  # manually patch it in installPhase
  dontPatchELF = true;
  buildInputs = [ autoPatchelfHook zlib libxml2 glibc stdenv.cc.cc rdma-core cudaPackages.cudatoolkit flock ];
  installPhase =
  # ref to upstream install script
  ''
    mkdir -p $out

    # mv install_components/Linux_x86_64/${version}/{comm_libs,compilers,cuda,examples,math_libs,profilers,REDIST} $out
    # for i in libibverbs.so* librdmacm.so* libnl-3.so* libnl-route-3.so*; do
    #   rm $out/comm_libs/mpi/lib/$i
    # done

    # current only install compilers
    mv install_components/Linux_x86_64/${version}/compilers/* $out
    autoPatchelf $out
    patchShebangs $out
    # $out/compilers/bin/makelocalrc -x $out/compilers/bin
    $out/bin/makelocalrc -x $out/bin -cuda ${cudaPackages.cudaVersion} -stdpar 80
    rm -f $out/glibc_version
  '';
  passthru =
  {
    isClang = false;
    langFortran = true;
    hardeningUnsupportedFlags = [ "fortify" "stackprotector" "pie" "pic" "strictoverflow" "format" ];
  };
}
