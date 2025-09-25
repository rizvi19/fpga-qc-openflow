
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

    top->clk = 0;
    top->start = 0;

    auto tick = [&]() {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(main_time);
        main_time += 5; // 5 ns half-period
    };

    // idle a few cycles
    for (int i = 0; i < 8; ++i) tick();

    // pulse start
    top->start = 1; tick();
    top->start = 0;

    bool seen_done = false;
    for (int i = 0; i < 200; ++i) {
        tick();
        if (top->done) { seen_done = true; break; }
    }

    printf("[SIM] done=%d, cycle_count=%u\n", (int)seen_done, top->cycle_count);

    top->final();
    tfp->close();
    delete tfp;
    delete top;
    return seen_done ? 0 : 1;
}
