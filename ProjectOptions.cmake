include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(CMakeTemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(CMakeTemplate_setup_options)
  option(CMakeTemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(CMakeTemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    CMakeTemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    CMakeTemplate_ENABLE_HARDENING
    OFF)

  CMakeTemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR CMakeTemplate_PACKAGING_MAINTAINER_MODE)
    option(CMakeTemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(CMakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(CMakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CMakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CMakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(CMakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(CMakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CMakeTemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(CMakeTemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(CMakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(CMakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(CMakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(CMakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CMakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CMakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CMakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(CMakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(CMakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CMakeTemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      CMakeTemplate_ENABLE_IPO
      CMakeTemplate_WARNINGS_AS_ERRORS
      CMakeTemplate_ENABLE_USER_LINKER
      CMakeTemplate_ENABLE_SANITIZER_ADDRESS
      CMakeTemplate_ENABLE_SANITIZER_LEAK
      CMakeTemplate_ENABLE_SANITIZER_UNDEFINED
      CMakeTemplate_ENABLE_SANITIZER_THREAD
      CMakeTemplate_ENABLE_SANITIZER_MEMORY
      CMakeTemplate_ENABLE_UNITY_BUILD
      CMakeTemplate_ENABLE_CLANG_TIDY
      CMakeTemplate_ENABLE_CPPCHECK
      CMakeTemplate_ENABLE_COVERAGE
      CMakeTemplate_ENABLE_PCH
      CMakeTemplate_ENABLE_CACHE)
  endif()

  CMakeTemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (CMakeTemplate_ENABLE_SANITIZER_ADDRESS OR CMakeTemplate_ENABLE_SANITIZER_THREAD OR CMakeTemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(CMakeTemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(CMakeTemplate_global_options)
  if(CMakeTemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    CMakeTemplate_enable_ipo()
  endif()

  CMakeTemplate_supports_sanitizers()

  if(CMakeTemplate_ENABLE_HARDENING AND CMakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CMakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR CMakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR CMakeTemplate_ENABLE_SANITIZER_THREAD
       OR CMakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${CMakeTemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${CMakeTemplate_ENABLE_SANITIZER_UNDEFINED}")
    CMakeTemplate_enable_hardening(CMakeTemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(CMakeTemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(CMakeTemplate_warnings INTERFACE)
  add_library(CMakeTemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  CMakeTemplate_set_project_warnings(
    CMakeTemplate_warnings
    ${CMakeTemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(CMakeTemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(CMakeTemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  CMakeTemplate_enable_sanitizers(
    CMakeTemplate_options
    ${CMakeTemplate_ENABLE_SANITIZER_ADDRESS}
    ${CMakeTemplate_ENABLE_SANITIZER_LEAK}
    ${CMakeTemplate_ENABLE_SANITIZER_UNDEFINED}
    ${CMakeTemplate_ENABLE_SANITIZER_THREAD}
    ${CMakeTemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(CMakeTemplate_options PROPERTIES UNITY_BUILD ${CMakeTemplate_ENABLE_UNITY_BUILD})

  if(CMakeTemplate_ENABLE_PCH)
    target_precompile_headers(
      CMakeTemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(CMakeTemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    CMakeTemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(CMakeTemplate_ENABLE_CLANG_TIDY)
    CMakeTemplate_enable_clang_tidy(CMakeTemplate_options ${CMakeTemplate_WARNINGS_AS_ERRORS})
  endif()

  if(CMakeTemplate_ENABLE_CPPCHECK)
    CMakeTemplate_enable_cppcheck(${CMakeTemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(CMakeTemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    CMakeTemplate_enable_coverage(CMakeTemplate_options)
  endif()

  if(CMakeTemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(CMakeTemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(CMakeTemplate_ENABLE_HARDENING AND NOT CMakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CMakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR CMakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR CMakeTemplate_ENABLE_SANITIZER_THREAD
       OR CMakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    CMakeTemplate_enable_hardening(CMakeTemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
