import { candidateScore } from '../src/questions/QuestionSelector';

function mk(
  questionCode: string,
  requirementRank: number,
  opts: {
    safetyBoost?: number;
    biodataStage?: number | null;
    priority?: number;
  } = {},
) {
  return {
    question: {
      question_code: questionCode,
      priority: opts.priority ?? 50,
      text: '',
      response_type: 'single_choice',
      is_active: true,
      default_value: null,
    },
    requirementLevel: 'conditionally_required',
    requirementRank,
    factCodes: [],
    primaryFactCode: null,
    triggerPriority: 50,
    safetyBoost: opts.safetyBoost ?? 0,
    informationGain: 0,
    differentialGain: 0,
    mechanismGain: 0,
    phenotypeGain: 0,
    pathwayGain: 0,
    redundancyPenalty: 0,
    biodataStage: opts.biodataStage ?? null,
    activationReason: '',
    ruleDelta: 0,
    moduleCodes: [],
    variantText: null,
  };
}

// objective sequence_no → exploration phase (10=characterize … 120=perspective)
const phases = (seq: number) =>
  new Map<string, number>([['Q', seq]]);

let failures = 0;
function check(name: string, ok: boolean, detail?: string) {
  if (!ok) failures += 1;
  console.log(`${ok ? 'OK   ' : 'FAIL '} ${name}${detail ? ' — ' + detail : ''}`);
}

const score = (c: ReturnType<typeof mk>, seq: number) =>
  candidateScore(c as never, phases(seq));

// 1. Phases ascend: characterize (10) < chronology (20) < … < health-seeking (100).
const rank2 = (seq: number) => score(mk('Q', 2), seq);
check(
  'phases ascend within same requirement',
  rank2(10) < rank2(20)
    && rank2(20) < rank2(30)
    && rank2(30) < rank2(40)
    && rank2(40) < rank2(50)
    && rank2(50) < rank2(60)
    && rank2(60) < rank2(70)
    && rank2(70) < rank2(100),
  `${rank2(10)} < ${rank2(100)}`,
);

// 2. Phase dominates requirement: a phase-2 conditional beats a phase-1
//    high_priority, and a phase-10 optional still comes after phase-2.
check(
  'phase dominates requirement within HPI',
  score(mk('Q', 3), 20) > score(mk('Q', 2), 10),
  `hp rank3 phase2 ${score(mk('Q', 3), 20)} vs cond rank2 phase1 ${score(mk('Q', 2), 10)}`,
);

// 3. Safety always leads: safety (rank 0) scores below every HPI phase.
const safety = candidateScore(
  mk('Q', 0, { safetyBoost: 2 }) as never,
  phases(10),
);
check('safety leads all HPI phases', safety < rank2(10), String(safety));

// 4. The whole battery precedes non-HPI conditional questions (band model):
//    every HPI phase, including the last (120), sorts before an unmapped
//    conditional question (requirementRank 2 → band 1800).
const unmappedCond = candidateScore(
  mk('EXAM', 2) as never,
  new Map<string, number>(),
);
check(
  'HPI battery precedes non-HPI conditional band',
  rank2(120) < unmappedCond,
  `${rank2(120)} < ${unmappedCond}`,
);

// 5. Biodata staged model is untouched by the HPI phase axis.
const biodata = candidateScore(
  mk('BIO', 2, { biodataStage: 1, priority: 10 }) as never,
  phases(10),
);
const biodataNoPhase = candidateScore(
  mk('BIO', 2, { biodataStage: 1, priority: 10 }) as never,
  new Map<string, number>(),
);
check(
  'biodata staging unaffected by HPI map',
  biodata === biodataNoPhase,
  `${biodata} vs ${biodataNoPhase}`,
);

// 6. Questions without an HPI objective keep the requirement-band model.
const expectedBand = 2 * 900 + 50 - 2250; // requirement + priority − trigger
check(
  'unmapped questions keep requirement band',
  unmappedCond === expectedBand,
  `${unmappedCond} vs ${expectedBand}`,
);

if (failures > 0) {
  console.error(`\n${failures} assertion(s) failed.`);
  process.exit(1);
}
console.log('\nOK — HPI exploration-phase ordering holds.');