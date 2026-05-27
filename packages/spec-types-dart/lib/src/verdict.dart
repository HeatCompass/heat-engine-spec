// Verdict-promotion state machine.
//
// Mirror of verdict.ts. Audit's prior_flag/next_flag/promotion_rule fields
// + result_summary phrasings match the TS impl byte-for-byte.

import 'audit.dart';
import 'types.dart';

const String _citation = 'heat-engine-spec design doc §2.5';

const Map<EnvironmentalFlag, int> _severity = {
  EnvironmentalFlag.white: 0,
  EnvironmentalFlag.green: 1,
  EnvironmentalFlag.yellow: 2,
  EnvironmentalFlag.red: 3,
  EnvironmentalFlag.black: 4,
};

SpecReturn<VerdictResult> promoteVerdict(
  VerdictInput input, [
  SpecContext? ctx,
]) {
  final priorVerdict = input.priorVerdict;
  final priorFlag = input.priorFlag;
  final currentFlag = input.currentFlag;
  final hasAlternate = input.hasAlternateAvailable;

  Verdict verdict;
  PromotionRule rule;
  bool changed;

  if (priorVerdict == null) {
    verdict = (_severity[currentFlag]! >= _severity[EnvironmentalFlag.red]!)
        ? Verdict.delay
        : Verdict.go;
    rule = PromotionRule.firstRunDefault;
    changed = false;
  } else if (priorFlag == currentFlag) {
    verdict = priorVerdict;
    rule = PromotionRule.noChange;
    changed = false;
  } else if (currentFlag == EnvironmentalFlag.black && hasAlternate) {
    verdict = Verdict.alternate;
    rule = PromotionRule.alternateAvailableAtBlack;
    changed = priorVerdict != verdict;
  } else if (_severity[currentFlag]! >= _severity[EnvironmentalFlag.red]!) {
    verdict = Verdict.delay;
    rule = PromotionRule.escalateToDelayOnRedOrBlack;
    changed = priorVerdict != verdict;
  } else {
    verdict = Verdict.go;
    rule = PromotionRule.deescalateToGo;
    changed = priorVerdict != verdict;
  }

  final result = VerdictResult(
    verdict: verdict,
    changedFromPrior: changed,
    promotionRule: rule,
  );

  String summary;
  switch (rule) {
    case PromotionRule.firstRunDefault:
      summary = 'first run, ${currentFlag.name} → ${verdict.name}';
      break;
    case PromotionRule.noChange:
      final held = priorVerdict == Verdict.delay ? ' (held)' : '';
      summary = 'no_change, ${currentFlag.name} → ${verdict.name}$held';
      break;
    case PromotionRule.alternateAvailableAtBlack:
      summary =
          '${priorFlag!.name} → ${currentFlag.name} + alternate → alternate';
      break;
    case PromotionRule.escalateToDelayOnRedOrBlack:
      summary = '${priorFlag!.name} → ${currentFlag.name}, escalate to delay';
      break;
    case PromotionRule.deescalateToGo:
      summary = '${priorFlag!.name} → ${currentFlag.name}, deescalate to go';
      break;
  }

  return SpecReturn(
    result: result,
    audit: buildAudit(
      fn: 'promoteVerdict',
      inputs: {
        'priorVerdict': priorVerdict?.name,
        'priorFlag': priorFlag?.name,
        'currentFlag': currentFlag.name,
        'hasAlternateAvailable': hasAlternate,
      },
      constants: const {},
      citation: _citation,
      resultSummary: summary,
      ctx: ctx,
      priorFlagSet: true,
      priorFlag: priorFlag,
      nextFlag: currentFlag,
      promotionRule: promotionRuleToWire(rule),
    ),
  );
}
