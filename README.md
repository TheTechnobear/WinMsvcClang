# WinMsvcClang

Cross compiling for windows msvc using `clangcl`  adapted from llvm WinMsvc.cmake


# create winsdk

```
xwin --arch x86_64 --accept-license  splat  --use-winsysroot-style     --preserve-ms-arch-notation     --output ~/toolchains/win/x86_64

win --arch aarch64 --accept-license  splat  --use-winsysroot-style     --preserve-ms-arch-notation     --output ~/toolchains/win/aarch64
````

move x86_64 cmake into the toolchains/win/x86_64
move aarch64 cmake into the toolchains/win/aarch64

```
# juce example compile
cmake -S . -B build-x86_64   -DCMAKE_TOOLCHAIN_FILE=$HOME/toolchains/win/x86_64/windows-cl.cmake    -DCMAKE_BUILD_TYPE=Release -DJUCE_BUILD_EXAMPLES=ON -DJUCE_BUILD_EXTRAS=ON  
``

``
cmake -S . -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=$HOME/toolchains/win/aarch64/windows-cl.cmake    -DCMAKE_BUILD_TYPE=Release -DJUCE_BUILD_EXAMPLES=ON -DJUCE_BUILD_EXTRAS=ON  
```
