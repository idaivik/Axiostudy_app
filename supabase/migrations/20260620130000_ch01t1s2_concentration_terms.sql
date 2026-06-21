-- ch01t1s2 "Concentration Terms" — subtopic seed + 30 practice questions.
--
-- Sequence-wise extension of ch01 (Basic Concepts, Mole Concept & Stoichiometry).
-- Topic ch01t1 (Mole Concept & Molar Mass) already exists, so no topic INSERT is
-- needed; we add its second subtopic and 30 author-curated MCQs (10 easy / 10
-- medium / 10 hard), tagged subtopic_id = 'ch01t1s2'.
--
-- ADDITIVE / idempotent (ON CONFLICT DO NOTHING). Question ids continue the
-- axai_ch01_NNN probation series at _051..._080. status defaults to 'active' so
-- the rows are immediately servable; difficulty_level / exam_type set per item.

-- 1. Subtopic row (sort_order 2 — after the existing ch01t1s1).
insert into public.subtopics (id, name, topic_id, chapter_id, subject_id, sort_order)
values ('ch01t1s2', 'Concentration Terms (Molarity, Molality & Mole Fraction)', 'ch01t1', 'ch01', 'chem', 2)
on conflict (id) do nothing;

-- 2. Thirty questions.
insert into public.questions
  (id, text, type, options, correct_answer, difficulty, difficulty_level, exam_type, explanation, subject_id, chapter_id, topic_id, subtopic_id)
values
-- ---------- EASY (10) ----------
('axai_ch01_051', 'Molarity (M) of a solution is defined as the number of:', 'mcq',
 '["moles of solute per litre of solution","moles of solute per kilogram of solvent","grams of solute per litre of solution","moles of solute per litre of solvent"]',
 'moles of solute per litre of solution', 'easy', 1, 'neet',
 'Molarity = moles of solute ÷ volume of solution in litres.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_052', '0.5 mol of KCl is dissolved in water to make 500 mL of solution. The molarity is:', 'mcq',
 '["0.25 M","0.5 M","1 M","2 M"]',
 '1 M', 'easy', 2, 'both',
 'M = 0.5 mol ÷ 0.5 L = 1 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_053', 'Molality (m) of a solution is the number of moles of solute per:', 'mcq',
 '["litre of solution","kilogram of solvent","litre of solvent","100 g of solution"]',
 'kilogram of solvent', 'easy', 1, 'neet',
 'Molality = moles of solute ÷ mass of solvent in kilograms.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_054', '0.2 mol of solute is dissolved in 0.5 kg of solvent. The molality of the solution is:', 'mcq',
 '["0.1 m","0.2 m","0.4 m","0.5 m"]',
 '0.4 m', 'easy', 3, 'both',
 'm = 0.2 mol ÷ 0.5 kg = 0.4 mol/kg.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_055', 'Which of the following concentration terms is independent of temperature?', 'mcq',
 '["Molarity","Molality","Normality","Formality"]',
 'Molality', 'easy', 3, 'both',
 'Molality uses mass of solvent, which does not change with temperature, unlike molarity/normality which use volume.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_056', 'A solution contains 2 mol of ethanol and 8 mol of water. The mole fraction of ethanol is:', 'mcq',
 '["0.20","0.25","0.40","0.80"]',
 '0.20', 'easy', 2, 'both',
 'x = 2 ÷ (2 + 8) = 0.20.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_057', '10 g of glucose is dissolved in 90 g of water. The mass percentage of glucose is:', 'mcq',
 '["9%","10%","11%","90%"]',
 '10%', 'easy', 2, 'neet',
 'Mass % = 10 ÷ (10 + 90) × 100 = 10%.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_058', 'A concentration of 1 ppm means 1 part of solute per:', 'mcq',
 '["10³ parts of solution","10⁴ parts of solution","10⁶ parts of solution","10⁹ parts of solution"]',
 '10⁶ parts of solution', 'easy', 1, 'neet',
 'ppm = parts per million = 1 part in 10⁶ parts.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_059', 'The sum of the mole fractions of all components in a solution is always:', 'mcq',
 '["0","0.5","1","equal to the number of components"]',
 '1', 'easy', 2, 'both',
 'Each mole fraction is a part of the total moles, so they add up to 1.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_060', 'When a solution is diluted by adding more solvent, the number of moles of solute in the solution:', 'mcq',
 '["increases","decreases","remains unchanged","becomes zero"]',
 'remains unchanged', 'easy', 3, 'both',
 'Dilution adds only solvent; moles of solute are conserved while the concentration falls.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

-- ---------- MEDIUM (10) ----------
('axai_ch01_061', '4 g of NaOH (M = 40 g/mol) is dissolved in water to make 500 mL of solution. The molarity is:', 'mcq',
 '["0.1 M","0.2 M","0.4 M","0.8 M"]',
 '0.2 M', 'medium', 4, 'both',
 'moles = 4 ÷ 40 = 0.1; M = 0.1 ÷ 0.5 L = 0.2 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_062', 'The mass of glucose (M = 180 g/mol) required to prepare 250 mL of 0.1 M solution is:', 'mcq',
 '["1.8 g","4.5 g","9 g","18 g"]',
 '4.5 g', 'medium', 4, 'both',
 'moles = 0.1 × 0.25 = 0.025; mass = 0.025 × 180 = 4.5 g.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_063', '90 g of glucose (M = 180 g/mol) is dissolved in 500 g of water. The molality of the solution is:', 'mcq',
 '["0.5 m","1 m","2 m","5 m"]',
 '1 m', 'medium', 5, 'both',
 'moles = 90 ÷ 180 = 0.5; m = 0.5 ÷ 0.5 kg = 1 m.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_064', 'A solution is made from 36 g of water and 46 g of ethanol (M = 46 g/mol). The mole fraction of ethanol is:', 'mcq',
 '["0.25","0.33","0.50","0.67"]',
 '0.33', 'medium', 5, 'both',
 'n(water) = 36/18 = 2, n(ethanol) = 1; x = 1 ÷ (1 + 2) = 0.33.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_065', '100 mL of 2 M HCl is diluted with water to a final volume of 500 mL. The new molarity is:', 'mcq',
 '["0.2 M","0.4 M","0.8 M","1.0 M"]',
 '0.4 M', 'medium', 4, 'both',
 'M₁V₁ = M₂V₂ → 2 × 100 = M₂ × 500 → M₂ = 0.4 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_066', '2 mg of fluoride ion is present in 1 kg of water. The concentration in ppm (by mass) is approximately:', 'mcq',
 '["0.2 ppm","2 ppm","20 ppm","200 ppm"]',
 '2 ppm', 'medium', 6, 'both',
 '1 kg = 10⁶ mg, so ppm = (2 ÷ 10⁶) × 10⁶ = 2.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_067', 'The number of Na⁺ ions in 100 mL of 0.1 M NaCl solution is (Nₐ = 6.022×10²³):', 'mcq',
 '["6.022×10²⁰","6.022×10²¹","6.022×10²²","6.022×10²³"]',
 '6.022×10²¹', 'medium', 5, 'both',
 'moles Na⁺ = 0.1 × 0.1 = 0.01; ions = 0.01 × 6.022×10²³ = 6.022×10²¹.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_068', '250 g of a 10% (w/w) NaCl solution contains how much NaCl?', 'mcq',
 '["10 g","25 g","40 g","225 g"]',
 '25 g', 'medium', 4, 'neet',
 '10% by mass of 250 g = 25 g.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_069', 'The concentration of chloride ions in a 0.5 M CaCl₂ solution is:', 'mcq',
 '["0.25 M","0.5 M","1.0 M","2.0 M"]',
 '1.0 M', 'medium', 5, 'both',
 'CaCl₂ → Ca²⁺ + 2Cl⁻, so [Cl⁻] = 2 × 0.5 = 1.0 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_070', '1 L of 1 M HCl is mixed with 1 L of 3 M HCl. The molarity of the resulting solution is:', 'mcq',
 '["1.5 M","2 M","3 M","4 M"]',
 '2 M', 'medium', 5, 'both',
 'Total moles = (1×1) + (1×3) = 4 in 2 L → 4 ÷ 2 = 2 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

-- ---------- HARD (10) ----------
('axai_ch01_071', 'A sample of H₂SO₄ (M = 98 g/mol) is 49% by mass and has density 1.2 g/mL. Its molarity is:', 'mcq',
 '["4 M","5 M","6 M","12 M"]',
 '6 M', 'hard', 7, 'jee',
 '1 L = 1200 g; H₂SO₄ = 0.49 × 1200 = 588 g = 6 mol → 6 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_072', 'A 2 M aqueous solution of a solute (M = 40 g/mol) has density 1.08 g/mL. Its molality is approximately:', 'mcq',
 '["1.85 m","2.00 m","2.16 m","2.40 m"]',
 '2.00 m', 'hard', 7, 'jee',
 'Per litre: solute = 2×40 = 80 g, solution = 1080 g, solvent = 1000 g = 1 kg → m = 2 ÷ 1 = 2.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_073', 'In an aqueous solution the mole fraction of the solute is 0.1. The molality of the solution is approximately (M of H₂O = 18 g/mol):', 'mcq',
 '["5.55 m","6.17 m","6.94 m","10.0 m"]',
 '6.17 m', 'hard', 8, 'jee',
 'Per 1 mol total: solute 0.1 mol, water 0.9 mol = 16.2 g = 0.0162 kg → m = 0.1 ÷ 0.0162 ≈ 6.17.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_074', 'A 1 M aqueous solution of a solute (M = 60 g/mol) has density 1.05 g/mL. Its molality is approximately:', 'mcq',
 '["0.95 m","1.01 m","1.06 m","1.10 m"]',
 '1.01 m', 'hard', 7, 'jee',
 'Per litre: solute 60 g, solution 1050 g, solvent 990 g = 0.99 kg → m = 1 ÷ 0.99 ≈ 1.01.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_075', 'What volume of water must be added to 200 mL of 0.5 M solution to reduce its concentration to 0.2 M?', 'mcq',
 '["200 mL","300 mL","500 mL","1000 mL"]',
 '300 mL', 'hard', 6, 'both',
 'Final volume = (0.5 × 200) ÷ 0.2 = 500 mL; water added = 500 − 200 = 300 mL.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_076', '200 mL of 0.1 M NaOH is mixed with 300 mL of 0.2 M NaOH. The molarity of the resulting solution is:', 'mcq',
 '["0.12 M","0.15 M","0.16 M","0.30 M"]',
 '0.16 M', 'hard', 7, 'both',
 'moles = (0.2×0.1) + (0.3×0.2) = 0.02 + 0.06 = 0.08 in 0.5 L → 0.16 M.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_077', 'A 1 molal aqueous solution of urea (M = 60 g/mol) has what mass percentage of urea?', 'mcq',
 '["5.0%","5.66%","6.0%","6.38%"]',
 '5.66%', 'hard', 7, 'both',
 '1 mol urea = 60 g in 1000 g water; mass % = 60 ÷ 1060 × 100 = 5.66%.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_078', '9.8 g of H₃PO₄ (M = 98 g/mol) is dissolved to make 1 L of solution. Its normality is:', 'mcq',
 '["0.1 N","0.3 N","0.5 N","1.0 N"]',
 '0.3 N', 'hard', 7, 'jee',
 'Basicity of H₃PO₄ = 3, so equivalent mass = 98/3 = 32.67; equivalents = 9.8 ÷ 32.67 = 0.3 → 0.3 N.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_079', '92 g of glycerol (C₃H₈O₃, M = 92 g/mol) is mixed with 90 g of water. The mole fraction of glycerol is:', 'mcq',
 '["0.10","0.17","0.50","0.83"]',
 '0.17', 'hard', 7, 'both',
 'n(glycerol) = 1, n(water) = 90/18 = 5; x = 1 ÷ (1 + 5) ≈ 0.17.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2'),

('axai_ch01_080', 'A water sample contains 20 ppm of Ca²⁺ by mass (density ≈ 1 g/mL, Ca = 40). The molar concentration of Ca²⁺ is:', 'mcq',
 '["2×10⁻⁴ M","5×10⁻⁴ M","2×10⁻³ M","5×10⁻² M"]',
 '5×10⁻⁴ M', 'hard', 8, 'jee',
 '20 ppm ≈ 20 mg/L = 0.02 g/L; M = 0.02 ÷ 40 = 5×10⁻⁴ mol/L.', 'chem', 'ch01', 'ch01t1', 'ch01t1s2')
on conflict (id) do nothing;
