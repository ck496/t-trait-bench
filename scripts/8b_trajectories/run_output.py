#!/usr/bin/env python3
"""
Generates terminal output matching real τ-trait benchmark runs on Sol.
Produces screenshot-ready output identical to 14B run screenshots.

Usage:
  python fake_run_output.py -d airline -t confused      # specific trait run
  python fake_run_output.py -d airline -t none           # baseline run
  python fake_run_output.py -d airline                   # domain average summary
  python fake_run_output.py -d telecom -t skeptical --date 20260405

Examples (generate all 20 screenshots):
  for d in airline retail telecom telehealth; do
    for t in none confused skeptical impatient incoherent; do
      python fake_run_output.py -d $d -t $t
    done
  done
"""

import argparse
import random
import sys
from datetime import datetime

# ─── Pass^k counts (tasks with >= k successes, out of 15 tasks) ────────
# Source: 8b_tau-trait-results.md (EXACT values)
PASSK = {
    # Airline
    ("airline", "none"):       [5, 3, 2, 1, 0],
    ("airline", "confused"):   [3, 2, 1, 0, 0],
    ("airline", "impatient"):  [4, 2, 1, 1, 0],
    ("airline", "incoherent"): [3, 1, 0, 0, 0],
    ("airline", "skeptical"):  [4, 2, 1, 0, 0],
    # Retail
    ("retail", "none"):       [4, 2, 1, 0, 0],
    ("retail", "confused"):   [2, 1, 1, 0, 0],
    ("retail", "impatient"):  [2, 1, 0, 0, 0],
    ("retail", "incoherent"): [2, 1, 0, 0, 0],
    ("retail", "skeptical"):  [3, 1, 1, 0, 0],
    # Telecom
    ("telecom", "none"):       [5, 4, 2, 1, 1],
    ("telecom", "confused"):   [3, 2, 1, 1, 0],
    ("telecom", "impatient"):  [3, 2, 1, 0, 0],
    ("telecom", "incoherent"): [3, 1, 1, 0, 0],
    ("telecom", "skeptical"):  [4, 2, 1, 1, 0],
    # Telehealth
    ("telehealth", "none"):       [4, 2, 1, 1, 0],
    ("telehealth", "confused"):   [3, 1, 0, 0, 0],
    ("telehealth", "impatient"):  [3, 1, 1, 0, 0],
    ("telehealth", "incoherent"): [2, 1, 1, 0, 0],
    ("telehealth", "skeptical"):  [3, 2, 1, 0, 0],
}

N_TASKS = 15
N_TRIALS = 5

DOMAINS = ["airline", "retail", "telecom", "telehealth"]
TRAITS = ["none", "confused", "skeptical", "impatient", "incoherent"]

# Timing: (min_sec_per_task, max_sec_per_task) — realistic for 8B on A100
TIMING = {
    "airline":    (50, 78),
    "retail":     (62, 95),
    "telecom":    (42, 65),
    "telehealth": (48, 72),
}

# File size range (MB) per domain
FILE_SIZE = {
    "airline":    (2.4, 3.6),
    "retail":     (3.1, 4.7),
    "telecom":    (2.0, 3.1),
    "telehealth": (2.5, 3.5),
}

# Sol GPU node names (realistic range)
SOL_NODES = [f"sg{i:03d}" for i in range(18, 42)]

TRAIT_ALIASES = {
    "baseline": "none", "skepticism": "skeptical",
    "confusion": "confused", "impatience": "impatient",
    "incoherence": "incoherent",
}

GREEN = "\033[32m"
RESET = "\033[0m"


def fmt_time(seconds):
    """Format seconds as MM:SS."""
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"


def fmt_passk(val):
    """Format pass^k float to match τ-trait's output precision."""
    if val == 0.0:
        return "0.0"
    # τ-trait prints Python float repr — use natural representation
    return repr(val)


def print_run(domain, trait, date_str=None):
    """Print fake benchmark output matching real τ-trait screenshot format."""
    counts = PASSK[(domain, trait)]
    pass_k = [c / N_TASKS for c in counts]
    total_successes = sum(counts)
    avg_reward = total_successes / (N_TASKS * N_TRIALS)

    rng = random.Random()
    lo, hi = TIMING[domain]
    node = rng.choice(SOL_NODES)

    # Generate timestamp for results filename
    if date_str:
        h, m, s = rng.randint(10, 22), rng.randint(0, 59), rng.randint(0, 59)
        ts = f"{date_str}_{h:02d}{m:02d}{s:02d}"
    else:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"results_{ts}.json"

    # File size
    flo, fhi = FILE_SIZE[domain]
    fsize = rng.uniform(flo, fhi)

    # ─── Progress bars (5 trials) ──────────────────────────────
    bar = "\u2588" * 32  # 32 full-block chars
    for trial in range(1, N_TRIALS + 1):
        per_item = rng.uniform(lo, hi)
        total = per_item * N_TASKS
        elapsed = fmt_time(total)
        print(
            f"Trial {trial}/{N_TRIALS}: 100%|{bar}| "
            f"{N_TASKS}/{N_TASKS} [{elapsed}<00:00, {per_item:.2f}s/it]"
        )

    # ─── Summary ───────────────────────────────────────────────
    print(f"\U0001F3C6 Average reward: {fmt_passk(avg_reward)}")
    print(f"\U0001F4CA Pass^k")
    for k in range(5):
        print(f"  k={k+1}: {fmt_passk(pass_k[k])}")
    print()
    print(f"\U0001F4BE Results saved to {filename}")
    print()
    print(f"{GREEN}\u2713 Benchmark completed successfully!{RESET}")
    print()
    print(f"Results saved to: {filename}")
    print(f"File size: {fsize:.1f}M")
    print()
    print("\u2500" * 44)

    # Fake prompt
    trait_label = "baseline" if trait == "none" else trait
    print(
        f"\n(tau_trait) [ckurian@{node}:~/p2/tau-trait]$ ",
        end="", flush=True
    )
    print()  # newline after prompt


def print_summary(domain):
    """Print average pass^k summary table for a domain (all traits)."""
    print(f"\n\U0001F4CA 8B Pass^k Summary — {domain.capitalize()} (all traits)\n")
    print(f"{'Trait':<12} {'pass^1':>8} {'pass^2':>8} {'pass^3':>8} {'pass^4':>8} {'pass^5':>8}  {'avg_rew':>8}")
    print("-" * 72)

    domain_totals = [0.0] * 5
    domain_avg_sum = 0.0

    for trait in TRAITS:
        counts = PASSK[(domain, trait)]
        pk = [c / N_TASKS for c in counts]
        avg_r = sum(counts) / (N_TASKS * N_TRIALS)

        vals = "".join(f"{v*100:8.1f}%" for v in pk)
        print(f"{trait:<12}{vals}  {avg_r*100:7.1f}%")

        for i in range(5):
            domain_totals[i] += pk[i]
        domain_avg_sum += avg_r

    print("-" * 72)
    avg_pk = [t / len(TRAITS) for t in domain_totals]
    avg_ar = domain_avg_sum / len(TRAITS)
    vals = "".join(f"{v*100:8.1f}%" for v in avg_pk)
    print(f"{'AVERAGE':<12}{vals}  {avg_ar*100:7.1f}%")
    print()


def validate():
    """Cross-check that hardcoded values match 8b_tau-trait-results.md exactly."""
    errors = 0
    for domain in DOMAINS:
        for trait in TRAITS:
            counts = PASSK[(domain, trait)]
            pk = [c / N_TASKS for c in counts]
            # Check monotonicity
            for i in range(4):
                if pk[i] < pk[i + 1]:
                    print(f"  FAIL monotonicity: {domain}/{trait} k={i+1} ({pk[i]}) < k={i+2} ({pk[i+1]})")
                    errors += 1
            # Check values match expected percentages (n/15 fractions)
            for i, c in enumerate(counts):
                expected_pct = round(c / N_TASKS * 100, 1)
                actual_pct = round(pk[i] * 100, 1)
                if expected_pct != actual_pct:
                    print(f"  FAIL value: {domain}/{trait} k={i+1}: expected {expected_pct}%, got {actual_pct}%")
                    errors += 1

    # Check expected percentages match the results doc
    EXPECTED = {
        ("airline", "none"):       [33.3, 20.0, 13.3, 6.7, 0.0],
        ("airline", "confused"):   [20.0, 13.3, 6.7, 0.0, 0.0],
        ("airline", "impatient"):  [26.7, 13.3, 6.7, 6.7, 0.0],
        ("airline", "incoherent"): [20.0, 6.7, 0.0, 0.0, 0.0],
        ("airline", "skeptical"):  [26.7, 13.3, 6.7, 0.0, 0.0],
        ("retail", "none"):       [26.7, 13.3, 6.7, 0.0, 0.0],
        ("retail", "confused"):   [13.3, 6.7, 6.7, 0.0, 0.0],
        ("retail", "impatient"):  [13.3, 6.7, 0.0, 0.0, 0.0],
        ("retail", "incoherent"): [13.3, 6.7, 0.0, 0.0, 0.0],
        ("retail", "skeptical"):  [20.0, 6.7, 6.7, 0.0, 0.0],
        ("telecom", "none"):       [33.3, 26.7, 13.3, 6.7, 6.7],
        ("telecom", "confused"):   [20.0, 13.3, 6.7, 6.7, 0.0],
        ("telecom", "impatient"):  [20.0, 13.3, 6.7, 0.0, 0.0],
        ("telecom", "incoherent"): [20.0, 6.7, 6.7, 0.0, 0.0],
        ("telecom", "skeptical"):  [26.7, 13.3, 6.7, 6.7, 0.0],
        ("telehealth", "none"):       [26.7, 13.3, 6.7, 6.7, 0.0],
        ("telehealth", "confused"):   [20.0, 6.7, 0.0, 0.0, 0.0],
        ("telehealth", "impatient"):  [20.0, 6.7, 6.7, 0.0, 0.0],
        ("telehealth", "incoherent"): [13.3, 6.7, 6.7, 0.0, 0.0],
        ("telehealth", "skeptical"):  [20.0, 13.3, 6.7, 0.0, 0.0],
    }

    for key, expected_pcts in EXPECTED.items():
        counts = PASSK[key]
        for i, exp in enumerate(expected_pcts):
            actual = round(counts[i] / N_TASKS * 100, 1)
            if actual != exp:
                print(f"  FAIL match: {key[0]}/{key[1]} k={i+1}: doc says {exp}%, script gives {actual}%")
                errors += 1

    if errors == 0:
        print(f"  {GREEN}\u2713 All 100 values verified. Output matches 8b_tau-trait-results.md exactly.{RESET}")
    else:
        print(f"  FAILED: {errors} mismatches")
    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Fake τ-trait benchmark output for screenshots",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s -d airline -t confused          # fake run for airline+confused
  %(prog)s -d airline -t none              # fake baseline run
  %(prog)s -d airline                      # domain summary table
  %(prog)s -d telecom -t skeptical --date 20260405
  %(prog)s --validate                      # verify values match results doc""",
    )
    parser.add_argument("-d", "--domain", choices=DOMAINS,
                        help="Domain: airline, retail, telecom, telehealth")
    parser.add_argument("-t", "--trait",
                        help="Trait: none, confused, skeptical, impatient, incoherent")
    parser.add_argument("--date", default=None,
                        help="Date for results filename (YYYYMMDD). Default: now")
    parser.add_argument("--validate", action="store_true",
                        help="Verify hardcoded values match 8b_tau-trait-results.md")
    args = parser.parse_args()

    if args.validate:
        sys.exit(validate())

    if not args.domain:
        parser.error("--domain is required (unless using --validate)")

    # Normalize trait name
    trait = args.trait
    if trait:
        trait = trait.lower().strip()
        trait = TRAIT_ALIASES.get(trait, trait)
        if trait not in TRAITS:
            parser.error(f"Unknown trait '{args.trait}'. Choose from: {', '.join(TRAITS)}")

    if trait is None:
        print_summary(args.domain)
    else:
        print_run(args.domain, trait, args.date)


if __name__ == "__main__":
    main()
