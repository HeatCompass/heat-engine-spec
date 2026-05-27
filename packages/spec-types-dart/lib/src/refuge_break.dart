// USMC 6200.1E §3.2 work/rest matrix.
//
// Mirror of refugeBreak.ts. Result summary strings + audit constants
// match the TS impl byte-for-byte so cross-language audit byte-equality
// holds at the canonical-json layer.

import 'audit.dart';
import 'types.dart';

const String _citation = 'USMC 6200.1E §3.2';

class _Cell {
  final int work;
  final int rest;
  final int? reassess;
  final bool cease;
  const _Cell(this.work, this.rest, this.reassess, this.cease);
}

class _FlagCells {
  final _Cell acclim;
  final _Cell unacclim;
  const _FlagCells(this.acclim, this.unacclim);
}

const Map<EnvironmentalFlag, _FlagCells> _ratios = {
  EnvironmentalFlag.white: _FlagCells(
    _Cell(60, 0, null, false),
    _Cell(50, 10, null, false),
  ),
  EnvironmentalFlag.green: _FlagCells(
    _Cell(50, 10, null, false),
    _Cell(40, 20, null, false),
  ),
  EnvironmentalFlag.yellow: _FlagCells(
    _Cell(45, 15, 6, false),
    _Cell(30, 30, 4, false),
  ),
  EnvironmentalFlag.red: _FlagCells(
    _Cell(30, 30, 4, false),
    _Cell(0, 0, null, true),
  ),
  EnvironmentalFlag.black: _FlagCells(
    _Cell(10, 50, 1, false),
    _Cell(0, 0, null, true),
  ),
};

SpecReturn<WorkRestInterval> workRestForFlag(
  RefugeBreakInput input, [
  SpecContext? ctx,
]) {
  final flag = input.flag;
  final acclim = input.acclimatized;
  final workMinutesRequested = input.workMinutesRequested;
  final cells = _ratios[flag]!;
  final cell = acclim ? cells.acclim : cells.unacclim;
  final branch = acclim ? 'acclim' : 'unacclim';

  final result = WorkRestInterval(
    workMinutes: cell.work,
    restMinutes: cell.rest,
    cyclesUntilReassessRequired: cell.reassess,
    ceaseWork: cell.cease,
  );

  final constants = <String, double>{};
  if (!cell.cease) {
    constants['${flag.name}_work_$branch'] = cell.work.toDouble();
    constants['${flag.name}_rest_$branch'] = cell.rest.toDouble();
    if (cell.reassess != null) {
      final key = acclim
          ? '${flag.name}_reassess_cycles'
          : '${flag.name}_reassess_cycles_unacclim';
      constants[key] = cell.reassess!.toDouble();
    }
  }

  String summary;
  if (cell.cease) {
    summary = '${flag.name}/$branch → cease_work';
  } else if (cell.reassess == 1) {
    summary =
        '${flag.name}/$branch → ${cell.work}w/${cell.rest}r, reassess every cycle';
  } else if (cell.reassess != null) {
    summary =
        '${flag.name}/$branch → ${cell.work}w/${cell.rest}r, reassess after ${cell.reassess} cycles';
  } else {
    summary = '${flag.name}/$branch → ${cell.work}w/${cell.rest}r';
  }
  if (workMinutesRequested <= 0) summary += ' (non_positive_work_window)';

  return SpecReturn(
    result: result,
    audit: buildAudit(
      fn: 'workRestForFlag',
      inputs: {
        'flag': flag.name,
        'acclimatized': acclim,
        'workMinutesRequested': workMinutesRequested,
      },
      constants: constants,
      citation: _citation,
      resultSummary: summary,
      ctx: ctx,
    ),
  );
}
