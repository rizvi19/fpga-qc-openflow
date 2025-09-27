
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vqc_top.h"
#include "Vqc_top___024root.h"
#include "Vqc_top__Syms.h"
#if VM_COVERAGE
#include "verilated_cov.h"
#endif
#include <algorithm>
#include <cmath>
#include <complex>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

static vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

static inline float q15_to_float(int16_t v) {
    return static_cast<float>(v) / 32768.0f;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    bool dump_vcd = std::getenv("DUMP_VCD") != nullptr;
    Verilated::traceEverOn(dump_vcd);

    // Parse +prog=
    std::string prog = "qft4";
    for (int i=1;i<argc;i++){
        std::string a(argv[i]);
        if (a.rfind("+prog=",0)==0) prog = a.substr(6);
    }
    uint32_t prog_id = 1; // qft4 default
    if (prog=="qft2") prog_id = 0;
    else if (prog=="qft4") prog_id = 1;
    else if (prog=="grover2") prog_id = 2;
    else if (prog=="bell2") prog_id = 3;
    else {
        std::cerr << "[TB][FAIL] unknown +prog option: " << prog << std::endl;
        return 1;
    }

    Vqc_top* top = new Vqc_top;

    VerilatedVcdC* tfp = nullptr;
    if (dump_vcd) {
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open("obj_dir/qc_top.vcd");
    }

    top->clk = 0;
    top->start = 0;
    top->prog_id = prog_id;

    auto cleanup = [&](bool write_cov) {
        if (top) {
            top->final();
#if VM_COVERAGE
            if (write_cov) {
                VerilatedCov::write();
            }
#endif
        }
        if (tfp) {
            tfp->close();
            delete tfp; tfp = nullptr;
        }
        delete top; top = nullptr;
    };

    auto fail = [&](const std::string& why) -> void {
        std::cerr << "[TB][FAIL] " << why << std::endl;
        cleanup(true);
        std::exit(1);
    };

    auto pass = [&](const std::string& name) -> void {
        std::cout << "[TB][PASS] " << name << std::endl;
    };

    auto tick = [&]() {
        top->clk = !top->clk;
        top->eval();
        if (tfp) {
            tfp->dump(main_time);
        }
        main_time += 5; // 5 ns half-period
    };

    // idle few cycles
    for (int i = 0; i < 8; ++i) tick();

    // start pulse
    top->start = 1; tick();
    top->start = 0;

    // run until done
    bool seen_done = false;
    for (int i = 0; i < 200000; ++i) {
        tick();
        if (top->done) { seen_done = true; break; }
    }

    printf("[SIM] prog=%s done=%d cycles=%u\n", prog.c_str(), (int)seen_done, top->cycle_count);

    if (!seen_done) {
        fail("timeout waiting for done");
    }

    constexpr int DIM = 1 << 4; // matches N_QUBITS=4
    auto* root = top->rootp;
    auto* syms = root->vlSymsp;
    auto& mem = syms->TOP__qc_top__u_sched__u_mem;
    std::vector<std::complex<float>> state(DIM);
    std::vector<float> mags(DIM);
    float total_prob = 0.0f;
    for (int i = 0; i < DIM; ++i) {
        int16_t r = static_cast<int16_t>(mem.mem_r[i]);
        int16_t im = static_cast<int16_t>(mem.mem_i[i]);
        std::complex<float> amp(q15_to_float(r), q15_to_float(im));
        state[i] = amp;
        mags[i] = std::norm(amp);
        total_prob += mags[i];
    }

    if (std::getenv("DUMP_STATE")) {
        std::cout << "[TB][STATE] " << prog << " amplitudes" << std::endl;
        for (int i = 0; i < DIM; ++i) {
            auto amp = state[i];
            std::cout << "  idx=" << i
                      << " real=" << amp.real()
                      << " imag=" << amp.imag()
                      << " mag2=" << mags[i] << std::endl;
        }
    }

    auto require_prob_close = [&](float expected, float tol, const std::string& label) {
        if (std::fabs(expected - total_prob) > tol) {
            fail(label + ": probability sum off (" + std::to_string(total_prob) + ")");
        }
    };

    if (prog == "qft2") {
        require_prob_close(1.0f, 0.02f, "qft2");
        const float expected = 0.25f;
        for (int i = 0; i < 4; ++i) {
            if (std::fabs(mags[i] - expected) > 0.02f) {
                fail("qft2: uneven superposition at index " + std::to_string(i));
            }
        }
        float tail = total_prob - expected * 4.0f;
        if (tail > 0.01f) {
            fail("qft2: leakage detected");
        }
        pass("qft2");
    } else if (prog == "qft4") {
        require_prob_close(1.0f, 0.02f, "qft4");
        const float expected = 1.0f / 16.0f;
        for (int i = 0; i < DIM; ++i) {
            if (std::fabs(mags[i] - expected) > 0.01f) {
                fail("qft4: uneven superposition at index " + std::to_string(i));
            }
        }
        pass("qft4");
    } else if (prog == "grover2") {
        require_prob_close(1.0f, 0.05f, "grover2");
        int peak = static_cast<int>(std::distance(mags.begin(), std::max_element(mags.begin(), mags.end())));
        if (peak != 3) {
            fail("grover2: expected maximum at index 3, got " + std::to_string(peak));
        }
        if (mags[peak] < 0.85f) {
            fail("grover2: marked state amplitude too small");
        }
        pass("grover2");
    } else if (prog == "bell2") {
        require_prob_close(1.0f, 0.05f, "bell2");
        float bell_mass = mags[0] + mags[3];
        if (std::fabs(mags[0] - 0.5f) > 0.05f || std::fabs(mags[3] - 0.5f) > 0.05f) {
            fail("bell2: amplitudes not 0.5 each");
        }
        if (std::fabs(mags[0] - mags[3]) > 0.05f) {
            fail("bell2: imbalance between |00> and |11>");
        }
        float others = total_prob - bell_mass;
        if (others > 0.05f) {
            fail("bell2: leakage detected");
        }
        pass("bell2");
    } else {
        fail("unhandled program check: " + prog);
    }

    cleanup(true);
    return 0;
}
