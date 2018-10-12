# Python functions for the kwiver project
# The following functions are defined:
#
#   kwiver_add_python_library
#   kwiver_add_python_module
#   kwiver_create_python_init
#   kwiver_create_python_plugin_init
#
# The following variables may be used to control the behavior of the functions:
#
#   copyright_header
#     The copyright header to place at the top of generated __init__.py files.
#
#   python_both_arch
#     If set, __init__.py file is created for both the archful and pure-Python
#     module paths (if in doubt, you probably don't need this; it's necessary
#     to support CPython and pure Python kwiver plugins).
#
# Their syntax is:
#
#   kwiver_add_python_library(name modpath [source ...])
#     Builds and installs a library to be used as a Python module which may be
#     imported. It is built as a shared library, installed (use no_install to
#     not install the module), placed into the proper subdirectory but not
#     exported. Any other control variables for kwiver_add_library are
#     available.
#
#   kwiver_add_python_module(name modpath module)
#     Installs a pure-Python module into the 'modpath' and puts it into the
#     correct place in the build tree so that it may be used with any built
#     libraries in any build configuration.
#
#   kwiver_create_python_init(modpath [module ...])
#     Creates an __init__.py package file which imports the modules in the
#     arguments for the package.
#
#   kwiver_create_python_plugin_init(modpath)
#     Creates an __init__.py for use as a plugin package (packages for kwiver
#     plugins written in Python must use one of these files as the package
#     __init__.py file and added to the KWIVER_PYTHON_MODULES environment
#     variable).

if ( NOT TARGET python)
  add_custom_target(python)
endif()

source_group("Python Files"  REGULAR_EXPRESSION ".*\\.py\\.in$")
source_group("Python Files"  REGULAR_EXPRESSION ".*\\.py$")

# Global collection variables
define_property(GLOBAL PROPERTY kwiver_python_modules
  BRIEF_DOCS "Python modules generated by kwiver"
  FULL_DOCS "List of Python modiles build."
  )


###
#
macro (_kwiver_create_safe_modpath    modpath    result)
  string(REPLACE "/" "." "${result}" "${modpath}")
endmacro ()


###
#
function (kwiver_add_python_library    name    modpath)
  _kwiver_create_safe_modpath("${modpath}" safe_modpath)

  set(library_subdir "/${kwiver_python_subdir}/${python_sitename}/${modpath}")
  set(component runtime)

  set(no_export ON)
  set(no_export_header ON)

  kwiver_add_library("python-${safe_modpath}-${name}" MODULE
    ${ARGN})

  if(MSVC)
    # Issues arise with the msvc compiler with some projects where it cannot
    # compile bindings without the optimizer expanding some inline functions (i.e. debug builds)
    # So always have the optimizer expand the inline functions in the python bindings projects
    target_compile_options("python-${safe_modpath}-${name}" PUBLIC "/Ob2")
  endif()

  set(pysuffix "${CMAKE_SHARED_MODULE_SUFFIX}")
  if (WIN32 AND NOT CYTWIN)
    set(pysuffix .pyd)
  endif ()

  set_target_properties("python-${safe_modpath}-${name}"
    PROPERTIES
      OUTPUT_NAME "${name}"
      PREFIX      ""
      SUFFIX      "${pysuffix}"
    )

  add_dependencies(python      "python-${safe_modpath}-${name}")
  set_property(GLOBAL APPEND PROPERTY kwiver_python_modules ${name})

endfunction ()


###
#
# kwiver_add_python_module(path modpath module)
#
# Installs a pure-Python module into the 'modpath' and puts it into the
# correct place in the build tree so that it may be used with any built
# libraries in any build configuration.
#
# Args:
#     path: Path to the python source (e.g. kwiver_process.py)
#     modpath: Python module path (e.g. kwiver/processes)
#     module: Python module name. This is the name used to import the code.
#         (e.g. kwiver_process)
#
# SeeAlso:
#     kwiver/CMake/utils/kwiver-utils-configuration.cmake
#     ../../sprokit/conf/sprokit-macro-python.cmake
#     ../../vital/bindings/python/vital/CMakeLists.txt
#     ../../sprokit/processes/bindings/python/kwiver/CMakeLists.txt
#     ../../sprokit/processes/bindings/python/kwiver/util/CMakeLists.txt
function (kwiver_add_python_module path     modpath    module)
  _kwiver_create_safe_modpath("${modpath}" safe_modpath)

  set(python_arch)
  set(python_noarchdir)

  if (WIN32)
    if (python_noarch)
      return ()
    else ()
      set(python_install_path lib)
    endif ()
  else ()
    if (python_noarch)
      set(python_noarchdir /noarch)
      set(python_install_path lib)
      set(python_arch u)
    else ()
      set(python_install_path "lib${LIB_SUFFIX}")
    endif ()
  endif ()

  if (CMAKE_CONFIGURATION_TYPES)
    set(kwiver_configure_cmake_args
      "\"-Dconfig=${CMAKE_CFG_INTDIR}/\"")
    set(kwiver_configure_extra_dests
      "${kwiver_python_output_path}/${python_noarchdir}\${config}/${python_sitename}/${modpath}/${module}.py")
  endif ()

  set(pyfile_src "${path}")
  set(pyfile_dst "${kwiver_python_output_path}${python_noarchdir}/${python_sitename}/${modpath}/${module}.py")
  # installation path for this module
  set(pypkg_install_path "${python_install_path}/${kwiver_python_subdir}/${python_sitename}/${modpath}")

  # copy and configure the source file into the binary directory
  if (KWIVER_SYMLINK_PYTHON)
    kwiver_symlink_file("python${python_arch}-${safe_modpath}-${module}"
      "${pyfile_src}"
      "${pyfile_dst}"
      PYTHON_EXECUTABLE)
  else()
    kwiver_configure_file("python${python_arch}-${safe_modpath}-${module}"
      "${pyfile_src}"
      "${pyfile_dst}"
      PYTHON_EXECUTABLE)
  endif()

  # install the configured binary to the kwiver python install path
  kwiver_install(
    FILES       "${pyfile_dst}"
    DESTINATION "${pypkg_install_path}"
    COMPONENT   runtime)

  add_dependencies(python
    "configure-python${python_arch}-${safe_modpath}-${module}")

  if (python_both_arch)
    set(python_both_arch)
    set(python_noarch TRUE)

    if (NOT WIN32)
      # this looks recursive
      kwiver_add_python_module(
        "${path}"
        "${modpath}"
        "${module}")
    endif ()
  endif ()
endfunction ()


###
#   kwiver_create_python_init(modpath [module ...])
#
#     Creates an __init__.py file for a core package which imports the modules
#     in the arguments for the package.
#
function (kwiver_create_python_init    modpath)
  _kwiver_create_safe_modpath("${modpath}" safe_modpath)

  set(init_template "${CMAKE_CURRENT_BINARY_DIR}/${safe_modpath}.__init__.py")

  if (NOT copyright_header)
    set(copyright_header "# Generated by kwiver")
  endif ()

  file(WRITE "${init_template}"      "${copyright_header}\n\n")

  file(APPEND "${init_template}"
    "from __future__ import absolute_import\n\n")

  foreach (module IN LISTS ARGN)
    file(APPEND "${init_template}"      "from .${module} import *\n")
  endforeach ()

  kwiver_add_python_module("${init_template}"
    "${modpath}"
    __init__)
endfunction ()


###
# Creates a default __init__.py file for a plugin package in the build
# directory.
#
function (kwiver_create_python_plugin_init modpath)
  _kwiver_create_safe_modpath("${modpath}" safe_modpath)

  set(init_template "${CMAKE_CURRENT_BINARY_DIR}/${safe_modpath}.__init__.py")

  if (NOT copyright_header)
    set(copyright_header "# Generated by kwiver")
  endif ()

  file(WRITE "${init_template}"     "${copyright_header}\n\n")
  file(APPEND "${init_template}"    "from pkgutil import extend_path\n")
  file(APPEND "${init_template}"    "__path__ = extend_path(__path__, __name__)\n")

  kwiver_add_python_module("${init_template}"
    "${modpath}"
    __init__)
endfunction ()
