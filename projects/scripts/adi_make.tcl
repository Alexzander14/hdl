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
  ## The folowing procedures are available:
  ##
  ## adi_make_lib <args>
  ##               -"all"(project libraries)
  ##               -"library name to build (plus path to it relative to library folder)
  ##                  e.g.: adi_make_lib xilinx/util_adxcvr
  ## adi_make_boot_bin - expected that u-boot*.elf (plus bl31.elf for zynq_mp)
  ##                     files are in the project folder"
  ## For more info please see: https://wiki.analog.com/resources/fpga/docs/build
  ##############################################################################
  # to print build step messages "set msg_level=1"
  variable msg_level
  set msg_level 0
  ##############################################################################

  # global variables
  variable build_list
  variable library_dir
  variable serch_pattern
  variable root_hdl_folder

  # init local namespace variables
  set build_list ""
  set makefiles ""
  set match ""

  # get library absolute path
  set root_hdl_folder ""
  set glb_path [pwd]
  if { [regexp projects $glb_path] } {
    regsub {/projects.*$} $glb_path "" root_hdl_folder
  } else {
    puts "ERROR: Not in hdl/* folder"
    return
  }

  set library_dir "$root_hdl_folder/library"

  # definie library dependancy search (Makefiles)
  set serch_pattern "LIB_DEPS.*="

  #############################################################################
  #############################################################################
  # procedures

  # have verbous or debug messages ############################################
  proc puts_msg_level { message } {
    global msg_level
    if { $msg_level == 1 } {
      puts $message
    }
  }

  # search for IP dependancies #################################################
  proc get_local_lib {} {

    global serch_pattern
    global library_dir
    global build_list
    set match ""
    set fp1 [open ./Makefile r]
    set file_data [read $fp1]
    close $fp1

    set lines [split $file_data \n]
    foreach line $lines {
      regexp $serch_pattern $line match
      if { $match != "" } {
        regsub -all $serch_pattern $line "" library
        set library [string trim $library]
        puts_msg_level "    - dependancy library $library"
        append build_list "$library "
        set match ""
      }
    }
  }

  # library build procedure ####################################################
  proc adi_make_lib { libraries } {

    global library_dir
    global build_list

    if { $libraries == "all" } {
      get_local_lib
      set libraries $build_list
    }

    set build_list ""
    set space " "
    puts "Building:"
    foreach b_lib $libraries {
      puts "- $b_lib"
      append build_list $library_dir/$b_lib$space
    }

    puts "Please wait, this might take a few minutes"
    set xsct_script "exec xsct $library_dir/scripts/adi_make_lib.tcl"
    eval $xsct_script $build_list ;# run in command line mode, with arguments
  }

  # boot_bin build procedure ###################################################
  proc adi_make_boot_bin {} {

    global root_hdl_folder
    set arm_tr_sw_elf "bl31.elf"
    set boot_bin_folder "boot_bin"
    set uboot_elf "u-boot.elf"
    catch { set uboot_elf "[glob "./u-boot*.elf"]" } err
    catch { set hdf_file "[glob "./*.sdk/system_top.hdf"]" } err

    puts_msg_level "root_hdl_folder $root_hdl_folder"
    puts_msg_level "uboot_elf $uboot_elf"
    puts_msg_level "hdf_file $hdf_file"

    set xsct_script "exec xsct $root_hdl_folder/projects/scripts/adi_make_boot_bin.tcl"
    set build_args "$hdf_file $uboot_elf $boot_bin_folder $arm_tr_sw_elf"
    puts "Please wait, this may take a few moments."
    eval $xsct_script $build_args
  }

  #############################################################################
  #############################################################################
