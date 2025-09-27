# Vivado non-project batch synthesis/implementation for qc_top
set PART xc7a200tfbg676-2
set TOP qc_top
set OUTDIR build
set RPTDIR $OUTDIR/reports

file mkdir $OUTDIR
file mkdir $RPTDIR

read_verilog -sv \
    [glob ../rtl/*.sv]

set_property top $TOP [current_fileset]
set_property PART $PART [current_fileset]

synth_design -top $TOP -part $PART
report_timing_summary -file $RPTDIR/timing_synth.rpt
report_utilization -file $RPTDIR/util_synth.rpt

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file $RPTDIR/timing_impl.rpt -no_header -no_detailed_paths
report_utilization -file $RPTDIR/util_impl.rpt

set tns [get_property SLACK [report_timing -max_paths 1 -return_string]]
puts "[synth] Worst slack: $tns"
if {[string match -* $tns]} {
  puts "[synth] Timing failed"
  exit 1
}
exit 0

