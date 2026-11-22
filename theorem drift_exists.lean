theorem drift_exists : pi_star / pi_euclid ≠ 1 := by
  unfold pi_star pi_euclid phi
  -- 1. pi < 3.1416, from Mathlib
  have hpi : Real.pi < 3.1416 := Real.pi_lt_31416
  -- 2. sqrt 5 < 2.237, because 2.237^2 = 5.004... > 5
  have h5 : Real.sqrt 5 < 2.237 := by
    rw [Real.sqrt_lt' (by norm_num : (0:ℝ) < 2.237)]
    norm_num
  -- 3. phi < 1.6185
  have hphi : (1 + Real.sqrt 5) / 2 < 1.6185 := by linarith
  -- 4. sqrt phi < 1.27324, because 1.27324^2 = 1.621... > 1.6185 > phi
  have hsqrtphi : Real.sqrt ((1 + Real.sqrt 5) / 2) < 1.27324 := by
    rw [Real.sqrt_lt' (by norm_num : (0:ℝ) < 1.27324)]
    nlinarith [hphi]
  -- 5. 4 / sqrt phi > 3.1416, because sqrt phi < 1.27324 and 4 / 1.27324 > 3.1416
  have hstar : 3.1416 < 4 / Real.sqrt ((1 + Real.sqrt 5) / 2) := by
    rw [lt_div_iff₀ (by positivity : (0:ℝ) < Real.sqrt ((1 + Real.sqrt 5) / 2))]
    nlinarith [hsqrtphi]
  -- 6. So pi* ≠ pi, so pi* / pi ≠ 1
  intro h
  have : 4 / Real.sqrt ((1 + Real.sqrt 5) / 2) = Real.pi := by
    have hne : Real.pi ≠ 0 := Real.pi_ne_zero
    field_simp at h
    linarith [h]
  linarith [hpi, hstar, this]
