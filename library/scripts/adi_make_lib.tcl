## ***************************************************************************
## ***************************************************************************
## Copyright 2014 - 2018 (c) Analog Devices, Inc. All rights reserved.
##
## In this HDL repository, there are many different and unique modules, consisting
## of various HDL (Verilog or VHDL) components. The individual modules are
## developed independently, and may be accompanied by separate and unique license
## terms.
##
## The user should read each of these license terms, and understand the
## freedoms and responsibilities that he or she has by using this source/core.
##
## This core is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
## A PARTICULAR PURPOSE.
##
## Redistribution and use of source or resulting binaries, with or without modification
## of this file, are permitted under one of the following two license terms:
##
##   1. The GNU General Public License version 2 as published by the
##      Free Software Foundation, which can be found in the top level directory
##      of this repository (LICENSE_GPL2), and also online at:
##      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
##
## OR
##
##   2. An ADI specific BSD license, which can be found in the top level directory
##      of this repository (LICENSE_ADIBSD), and also on-line at:
##      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
##      This will allow to generate bit files and not release the source code,
##      as long as it attaches to an ADI device.
##
## ***************************************************************************
## ***************************************************************************

  ##############################################################################
  # to print build step messages "msg_level=1"
  variable msg_level
  set msg_level 0
  ##############################################################################

  # global variables
  variable library_dir
  variable done_list
  variable serch_pattern

  # init local namespace variables
  set done_list ""
  set build_list ""
  set makefiles ""
  set depend_lib ""
  set match ""

  # searching for subdir libraries in path for first argument
  set first_lib [lindex $argv 0]
  if { $first_lib == "" } {
    set first_lib "."
  }

  # get library absolute path
  set glb_path [file normalize $first_lib]
  if { [regexp library $glb_path] } {
    regsub {library.*$} $glb_path library library_dir
  } else {
    puts "ERROR: Not in library/* folder or argument to an IP located in library folder"
    return
  }

  # geting all parsed arguments (libraries)
  set index 0
  set library_element(1) $first_lib
  foreach argument $argv {
    incr index 1
    set library_element($index) $argument
  }

  # definie library dependancy search (Makefiles)
  set serch_pattern "XILINX_.*_DEPS.*="

  #############################################################################
  # library build procedures
  #############################################################################

  # have verbous or debug messages ############################################
  proc puts_msg_level { message } {
    global msg_level
    if { $msg_level == 1 } {
      puts $message
    }
  }

  # search for IP dependancies #################################################
  proc search_dependancy { path } {

    puts_msg_level "DEBUG search_dependancy proc"
    global serch_pattern
    global library_dir
    set match ""
    set fp1 [open $library_dir/$path/Makefile r]
    set file_data [read $fp1]
    close $fp1

    set lines [split $file_data \n]
    foreach line $lines {
      regexp $serch_pattern $line match
      if { $match != "" } {
        regsub -all $serch_pattern $line "" lib_dep
        set lib_dep [string trim $lib_dep]
	puts_msg_level "    > dependancy library $lib_dep"
	# build dependancy
        build_lib $lib_dep
	set match ""
      }
    }
  }

  # build procedure ############################################################
  proc build_lib { library } {

    puts_msg_level "DEBUG build_lib proc"
    global done_list
    global library_dir

    # determine if the IP was previously build in the current adi_make_lib.tcl call
    if { [regexp $library $done_list] } {
      puts_msg_level "Build previously done on $library"
      return
    } else {
      puts_msg_level "- Start build of $library"
    }
    puts_msg_level "- Search dependancies for $library"

    # search for current IP dependancies
    search_dependancy $library

    puts_msg_level "- Continue build on $library"
    set ip_name "[file tail $library]_ip"

    cd $library_dir/${library}
    exec vivado -mode batch -source "$library_dir/${library}/${ip_name}.tcl"
    file copy -force ./vivado.log ./${ip_name}.log
    puts "- Done building $library"
    append done_list $library
  }

  #############################################################################

  # search for all posible IPs in the given argument paths
  if { $index == 0 } {
    set index 1
  }
  for {set y 1} {$y<=$index} {incr y} {
    set dir "$library_element($y)/"
    #search 4 level subdirectories for Makefiles
    for {set x 1} {$x<=4} {incr x} {
    catch { append makefiles " [glob "${dir}Makefile"]" } err
      append dir "*/"
    }
  }

  if { $makefiles == "" } {
    puts "ERROR: Wrong path to IP or the IP does not have a Makefile starting from \"$library_element(1)\""
  }

  # filter out non buildable libs (non *_ip.tcl)
  set buildable ""
  foreach fs $makefiles {
    set ip_dir [file dirname $fs]
    set ip_name "[file tail $ip_dir]_ip.tcl"
    if { [file exists $ip_dir/$ip_name] } {
      append buildable "$fs "
    }
  }
  set makefiles $buildable

  # build all detected IPs
  foreach fs $makefiles {
    regsub /Makefile $fs "" fs
    if { $fs == "." } {
      set fs [file normalize $fs]
      set fs [file tail $fs]
      set fs [string trim $fs]
    }
    regsub .*library/ $fs "" fs
    build_lib $fs
  }

  #############################################################################
  #############################################################################
