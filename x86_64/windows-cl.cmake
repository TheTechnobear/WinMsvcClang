include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_VERSION 10.0)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

# ---------------------------------------------------------------------------
# Toolchain locations
# ---------------------------------------------------------------------------

set(LLVM_NATIVE_TOOLCHAIN "/usr/lib/llvm-21")
set(LLVM_WINSYSROOT "$ENV{HOME}/toolchains/win/x86_64")

set(MSVC_VER "14.44.17.14")
set(WINSDK_VER "10.0.26100")

set(TRIPLE_ARCH "x86_64")
set(WINSDK_ARCH "x64")

set(ATLMFC_LIB
    "${LLVM_WINSYSROOT}/VC/Tools/MSVC/${MSVC_VER}/atlmfc/lib")
set(MSVC_INCLUDE
    "${LLVM_WINSYSROOT}/VC/Tools/MSVC/${MSVC_VER}/include")
set(MSVC_LIB
    "${LLVM_WINSYSROOT}/VC/Tools/MSVC/${MSVC_VER}/lib")

set(WINSDK_INCLUDE
    "${LLVM_WINSYSROOT}/Windows Kits/10/Include/${WINSDK_VER}")
set(WINSDK_LIB
    "${LLVM_WINSYSROOT}/Windows Kits/10/Lib/${WINSDK_VER}")

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if(NOT EXISTS "${LLVM_NATIVE_TOOLCHAIN}/bin/clang-cl" OR
   NOT EXISTS "${LLVM_NATIVE_TOOLCHAIN}/bin/lld-link")
    message(FATAL_ERROR
        "LLVM_NATIVE_TOOLCHAIN does not contain clang-cl/lld-link")
endif()

if(NOT EXISTS "${MSVC_INCLUDE}" OR NOT EXISTS "${MSVC_LIB}")
    message(FATAL_ERROR
        "MSVC headers/libraries not found")
endif()

if(NOT EXISTS "${WINSDK_INCLUDE}" OR NOT EXISTS "${WINSDK_LIB}")
    message(FATAL_ERROR
        "Windows SDK not found")
endif()

if(NOT EXISTS "${WINSDK_INCLUDE}/um/Windows.h")
    message(FATAL_ERROR "Cannot find Windows.h")
endif()

# Linux filesystem is case-sensitive, Windows filesystem is not.
if(NOT EXISTS "${WINSDK_INCLUDE}/um/WINDOWS.H")
    set(case_sensitive_filesystem TRUE)
endif()

# ---------------------------------------------------------------------------
# Exact LLVM VFS overlay generation
# ---------------------------------------------------------------------------

function(generate_winsdk_vfs_overlay winsdk_include_dir output_path)
    set(include_dirs)

    file(GLOB_RECURSE entries LIST_DIRECTORIES true
         "${winsdk_include_dir}/*")

    foreach(entry ${entries})
        if(IS_DIRECTORY "${entry}")
            list(APPEND include_dirs "${entry}")
        endif()
    endforeach()

    file(WRITE "${output_path}" "version: 0\n")
    file(APPEND "${output_path}" "case-sensitive: false\n")
    file(APPEND "${output_path}" "roots:\n")

    foreach(dir ${include_dirs})
        file(GLOB headers RELATIVE "${dir}" "${dir}/*.h")

        if(NOT headers)
            continue()
        endif()

        file(APPEND "${output_path}"
             "  - name: \"${dir}\"\n")
        file(APPEND "${output_path}"
             "    type: directory\n")
        file(APPEND "${output_path}"
             "    contents:\n")

        foreach(header ${headers})
            file(APPEND "${output_path}"
                 "      - name: \"${header}\"\n")
            file(APPEND "${output_path}"
                 "        type: file\n")
            file(APPEND "${output_path}"
                 "        external-contents: \"${dir}/${header}\"\n")
        endforeach()
    endforeach()
endfunction()

# ---------------------------------------------------------------------------
# Case-correcting library symlinks
# ---------------------------------------------------------------------------

function(generate_winsdk_lib_symlinks winsdk_um_lib_dir output_dir)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_dir}")

    file(GLOB libraries
         RELATIVE "${winsdk_um_lib_dir}"
         "${winsdk_um_lib_dir}/*")

    foreach(library ${libraries})
        string(TOLOWER "${library}" all_lowercase_symlink_name)

        if(NOT library STREQUAL all_lowercase_symlink_name)
            execute_process(
                COMMAND "${CMAKE_COMMAND}"
                        -E create_symlink
                        "${winsdk_um_lib_dir}/${library}"
                        "${output_dir}/${all_lowercase_symlink_name}")
        endif()

        get_filename_component(name_we "${library}" NAME_WE)
        get_filename_component(ext "${library}" EXT)
        string(TOLOWER "${ext}" lowercase_ext)

        set(lowercase_ext_symlink_name
            "${name_we}${lowercase_ext}")

        if(NOT library STREQUAL lowercase_ext_symlink_name AND
           NOT all_lowercase_symlink_name STREQUAL lowercase_ext_symlink_name)
            execute_process(
                COMMAND "${CMAKE_COMMAND}"
                        -E create_symlink
                        "${winsdk_um_lib_dir}/${library}"
                        "${output_dir}/${lowercase_ext_symlink_name}")
        endif()
    endforeach()
endfunction()

function(generate_msvc_lib_symlinks msvc_lib_dir output_dir)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_dir}")

    file(GLOB libraries
         RELATIVE "${msvc_lib_dir}"
         "${msvc_lib_dir}/*.lib")

    foreach(library ${libraries})
        get_filename_component(name_wle "${library}" NAME_WLE)
        get_filename_component(ext "${library}" LAST_EXT)

        string(TOLOWER "${ext}" lowercase_ext)
        string(TOUPPER "${name_wle}" all_uppercase_symlink_name_wle)

        set(uppercase_symlink_name
            "${all_uppercase_symlink_name_wle}${lowercase_ext}")

        if(NOT library STREQUAL uppercase_symlink_name)
            execute_process(
                COMMAND "${CMAKE_COMMAND}"
                        -E create_symlink
                        "${msvc_lib_dir}/${library}"
                        "${output_dir}/${uppercase_symlink_name}")
        endif()
    endforeach()
endfunction()

# ---------------------------------------------------------------------------
# Compilers
# ---------------------------------------------------------------------------

set(CMAKE_C_COMPILER
    "${LLVM_NATIVE_TOOLCHAIN}/bin/clang-cl"
    CACHE FILEPATH "")

set(CMAKE_CXX_COMPILER
    "${LLVM_NATIVE_TOOLCHAIN}/bin/clang-cl"
    CACHE FILEPATH "")

set(CMAKE_LINKER
    "${LLVM_NATIVE_TOOLCHAIN}/bin/lld-link"
    CACHE FILEPATH "")

set(CMAKE_AR
    "${LLVM_NATIVE_TOOLCHAIN}/bin/llvm-lib"
    CACHE FILEPATH "")

# ---------------------------------------------------------------------------
# Compiler flags
# ---------------------------------------------------------------------------

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")

set(COMPILE_FLAGS
    -D_CRT_SECURE_NO_WARNINGS
    --target=${TRIPLE_ARCH}-windows-msvc
    -fms-compatibility-version=19.28
    -vctoolsversion ${MSVC_VER}
    -winsdkversion ${WINSDK_VER}
    -winsysroot ${LLVM_WINSYSROOT}
)

# ---------------------------------------------------------------------------
# VFS overlay
# ---------------------------------------------------------------------------

if(case_sensitive_filesystem)

    set(winsdk_vfs_overlay_path
        "${CMAKE_BINARY_DIR}/winsdk_vfs_overlay.yaml")

    generate_winsdk_vfs_overlay(
        "${WINSDK_INCLUDE}"
        "${winsdk_vfs_overlay_path}")

    list(APPEND COMPILE_FLAGS
        -Xclang
        -ivfsoverlay
        -Xclang
        "${winsdk_vfs_overlay_path}")

endif()

string(REPLACE ";" " " COMPILE_FLAGS "${COMPILE_FLAGS}")

# Add case-sensitive aliases required by Windows library names
function(generate_winsdk_lib_case_aliases winsdk_um_lib_dir output_dir)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E create_symlink
            "${winsdk_um_lib_dir}/dwrite.lib"
            "${output_dir}/Dwrite.lib")

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E create_symlink
            "${winsdk_um_lib_dir}/d2d1.lib"
            "${output_dir}/D2d1.lib")

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E create_symlink
            "${winsdk_um_lib_dir}/dcomp.lib"
            "${output_dir}/DComp.lib")
endfunction()


set(CMAKE_RC_FLAGS_INIT
    "--target=${TRIPLE_ARCH}-windows-msvc "
    "-fms-compatibility-version=19.28 "
    "-vctoolsversion ${MSVC_VER} "
    "-winsdkversion ${WINSDK_VER} "
    "-winsysroot \"${LLVM_WINSYSROOT}\" "
    "-Xclang -ivfsoverlay "
    "-Xclang \"${winsdk_vfs_overlay_path}\"")

string(REPLACE ";" " " CMAKE_RC_FLAGS_INIT "${CMAKE_RC_FLAGS_INIT}")


string(APPEND CMAKE_C_FLAGS_INIT
    " ${COMPILE_FLAGS}")

string(APPEND CMAKE_CXX_FLAGS_INIT
    " ${COMPILE_FLAGS}")

# ---------------------------------------------------------------------------
# Linker flags
# ---------------------------------------------------------------------------

set(LINK_FLAGS
    /manifest:no
    -libpath:"${ATLMFC_LIB}/${WINSDK_ARCH}"
    -libpath:"${MSVC_LIB}/${WINSDK_ARCH}"
    -libpath:"${WINSDK_LIB}/ucrt/${WINSDK_ARCH}"
    -libpath:"${WINSDK_LIB}/um/${WINSDK_ARCH}"
)

if(case_sensitive_filesystem)

    set(winsdk_lib_symlinks_dir
        "${CMAKE_BINARY_DIR}/winsdk_lib_symlinks")

    generate_winsdk_lib_symlinks(
        "${WINSDK_LIB}/um/${WINSDK_ARCH}"
        "${winsdk_lib_symlinks_dir}")

    generate_winsdk_lib_case_aliases(
        "${WINSDK_LIB}/um/${WINSDK_ARCH}"
        "${winsdk_lib_symlinks_dir}"
    )

    list(APPEND LINK_FLAGS
        -libpath:"${winsdk_lib_symlinks_dir}")

    set(msvc_lib_symlinks_dir
        "${CMAKE_BINARY_DIR}/msvc_lib_symlinks")

    generate_msvc_lib_symlinks(
        "${MSVC_LIB}/${WINSDK_ARCH}"
        "${msvc_lib_symlinks_dir}")

    list(APPEND LINK_FLAGS
        -libpath:"${msvc_lib_symlinks_dir}")

endif()

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.25")
    list(TRANSFORM LINK_FLAGS
         PREPEND "${CMAKE_CXX_LINKER_WRAPPER_FLAG}")
endif()

string(REPLACE ";" " " LINK_FLAGS "${LINK_FLAGS}")

string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT
    " ${LINK_FLAGS}")

string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT
    " ${LINK_FLAGS}")

string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT
    " ${LINK_FLAGS}")

# Let projects explicitly specify their Windows libraries.

# Don't let try_compile configurations lose the important variables.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    LLVM_NATIVE_TOOLCHAIN
    LLVM_WINSYSROOT
    MSVC_VER
    WINSDK_VER
    winsdk_vfs_overlay_path
    msvc_lib_symlinks_dir
    winsdk_lib_symlinks_dir)
