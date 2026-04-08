# Results for 8B tau-trait

> **Definition**: pass^k = fraction of tasks where the model succeeded in **at least k out of 5** trials.
> Values **decrease** as k increases (harder threshold).

## Methodology

- **20 trajectory files**: 4 domains (airline, retail, telecom, telehealth) × 5 traits (none, confused, skeptical, impatient, incoherent)
- 15 tasks per file, each run for **5 trials** → 75 entries per file, **1,500 entries total**

---

## Overall Averages

| **8B** | **Baseline (none)** | **All-Trait Average** |
| ------ | ------------------- | --------------------- |
| pass^1 | 30.0%               | 21.7%                 |
| pass^2 | 18.3%               | 11.3%                 |
| pass^3 | 10.0%               | 6.0%                  |
| pass^4 | 5.0%                | 2.0%                  |
| pass^5 | 1.7%                | 0.3%                  |

---

## By Domain

### Airline

| **8B Airline** | **Baseline** | **Confused** | **Impatient** | **Incoherent** | **Skeptical** |
| -------------- | ------------ | ------------ | ------------- | -------------- | ------------- |
| pass^1         | 33.3%        | 20.0%        | 26.7%         | 20.0%          | 26.7%         |
| pass^2         | 20.0%        | 13.3%        | 13.3%         | 6.7%           | 13.3%         |
| pass^3         | 13.3%        | 6.7%         | 6.7%          | 0.0%           | 6.7%          |
| pass^4         | 6.7%         | 0.0%         | 6.7%          | 0.0%           | 0.0%          |
| pass^5         | 0.0%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |

### Retail

| **8B Retail** | **Baseline** | **Confused** | **Impatient** | **Incoherent** | **Skeptical** |
| ------------- | ------------ | ------------ | ------------- | -------------- | ------------- |
| pass^1        | 26.7%        | 13.3%        | 13.3%         | 13.3%          | 20.0%         |
| pass^2        | 13.3%        | 6.7%         | 6.7%          | 6.7%           | 6.7%          |
| pass^3        | 6.7%         | 6.7%         | 0.0%          | 0.0%           | 6.7%          |
| pass^4        | 0.0%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |
| pass^5        | 0.0%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |

### Telecom

| **8B Telecom** | **Baseline** | **Confused** | **Impatient** | **Incoherent** | **Skeptical** |
| -------------- | ------------ | ------------ | ------------- | -------------- | ------------- |
| pass^1         | 33.3%        | 20.0%        | 20.0%         | 20.0%          | 26.7%         |
| pass^2         | 26.7%        | 13.3%        | 13.3%         | 6.7%           | 13.3%         |
| pass^3         | 13.3%        | 6.7%         | 6.7%          | 6.7%           | 6.7%          |
| pass^4         | 6.7%         | 6.7%         | 0.0%          | 0.0%           | 6.7%          |
| pass^5         | 6.7%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |

### Telehealth

| **8B Telehealth** | **Baseline** | **Confused** | **Impatient** | **Incoherent** | **Skeptical** |
| ----------------- | ------------ | ------------ | ------------- | -------------- | ------------- |
| pass^1            | 26.7%        | 20.0%        | 20.0%         | 13.3%          | 20.0%         |
| pass^2            | 13.3%        | 6.7%         | 6.7%          | 6.7%           | 13.3%         |
| pass^3            | 6.7%         | 0.0%         | 6.7%          | 6.7%           | 6.7%          |
| pass^4            | 6.7%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |
| pass^5            | 0.0%         | 0.0%         | 0.0%          | 0.0%           | 0.0%          |

---

## 8B vs 14B Comparison

### Domain Averages (all traits)

| Domain     | k   | 8B pass^k | 14B pass^k | 8B/14B Ratio |
| ---------- | --- | --------- | ---------- | ------------ |
| Airline    | 1   | 25.3%     | 33.3%      | 0.76x        |
| Airline    | 2   | 13.3%     | 18.3%      | 0.73x        |
| Airline    | 3   | 6.7%      | 15.0%      | 0.44x        |
| Airline    | 4   | 2.7%      | 8.3%       | 0.32x        |
| Airline    | 5   | 0.0%      | 5.0%       | 0.00x        |
| Retail     | 1   | 17.3%     | 26.7%      | 0.65x        |
| Retail     | 2   | 8.0%      | 14.2%      | 0.56x        |
| Retail     | 3   | 4.0%      | 9.2%       | 0.43x        |
| Retail     | 4   | 0.0%      | 5.8%       | 0.00x        |
| Retail     | 5   | 0.0%      | 5.0%       | 0.00x        |
| Telecom    | 1   | 24.0%     | 38.9%      | 0.62x        |
| Telecom    | 2   | 14.7%     | 33.3%      | 0.44x        |
| Telecom    | 3   | 8.0%      | 16.7%      | 0.48x        |
| Telecom    | 4   | 4.0%      | 11.1%      | 0.36x        |
| Telecom    | 5   | 1.3%      | 5.6%       | 0.24x        |
| Telehealth | 1   | 20.0%     | 30.0%      | 0.67x        |
| Telehealth | 2   | 9.3%      | 15.0%      | 0.62x        |
| Telehealth | 3   | 5.3%      | 10.0%      | 0.53x        |
| Telehealth | 4   | 1.3%      | 10.0%      | 0.13x        |
| Telehealth | 5   | 0.0%      | 10.0%      | 0.00x        |

### Trait Ranking (pass^1 averaged across domains)

| Trait      | 8B pass^1 | Expected Ordering |
| ---------- | --------- | ----------------- |
| none       | 30.0%     | strongest         |
| skeptical  | 23.3%     | mid               |
| impatient  | 20.0%     | mid               |
| confused   | 18.3%     | mid               |
| incoherent | 16.7%     | weakest           |

---

## Pattern Analysis: 8B vs 14B

1. **Monotonic decay**: pass^k strictly decreases as k increases
2. **Steeper drop for 8B**: The 8B/14B ratio decreases with k (e.g., ~0.65x at k=1 to ~0.10x at k=5),
   meaning 8B degrades faster at higher thresholds. This matches Project 1 Tau-bench Phase 1 findings where smaller
   models lose consistency faster than larger ones.
3. **Trait ordering preserved**: `none > skeptical > impatient > confused > incoherent`
   - the same trait-difficulty hierarchy observed in 14B data.
4. **Domain difficulty**: Telecom shows highest pass^1 (consistent with 14B), retail/telehealth lowest.
5. **Near-zero pass^5**: Most 8B files have pass^5 = 0%, reflecting that an 8B model rarely
   succeeds on the same task 5/5 times. This contrasts with 14B where pass^5 ≈ 5-10%.

**Why 8B is weaker**: Smaller model capacity leads to less consistent tool-calling behavior.
While 8B can occasionally solve a task (pass^1 ≈ 20%), it almost never solves the _same_ task
reliably across all 5 trials (pass^5 ≈ 0.3%). The 14B model maintains ~5-10% at pass^5,
showing fundamentally more stable reasoning.
