#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vqc_top.h"
#include <cstdio>
#include <cstdint>

static vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vqc_top* top = new Vqc_top;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("obj_dir/qc_top.vcd");

    // Resetless simple design; just drive clock/start
    top->clk = 0;
    top->start = 0;

    auto tick = [&]() {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(main_time);
        main_time += 5; // 5 ns half-period => 100 MHz illustrative
    };

    // 4 cycles idle
    for (int i = 0; i < 8; ++i) tick();

    // Pulse start for 1 cycle
    top->start = 1;
    tick();
    top->start = 0;

    // Run for some cycles, expect 'done' to assert (stub does when start seen)
    bool seen_done = false;
    for (int i = 0; i < 50; ++i) {
        tick();
        if (top->done) seen_done = true;
    }

    printf("[SIM] done=%d (expected 1)\n", (int)seen_done);

    // Finish
    top->final();
    tfp->close();
    delete tfp;
    delete top;

    return seen_done ? 0 : 1;
}
