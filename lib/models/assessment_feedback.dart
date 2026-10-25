String overallScoreText(dynamic value) =>
    value is num && value.isFinite ? value.toStringAsFixed(1) : 'Unavailable';

String assessmentFeedback(Map<String, dynamic> session) {
  final raw = session['assessmentDetails'];
  if (raw is! Map || raw['version'] != 1) {
    final availability = session['analysisAvailability'];
    final fillers = session['fillerAnalysis'];
    final coverage = fillers is Map ? fillers['coverage'] : null;
    final partial =
        (coverage is Map && coverage['status'] == 'mismatch') ||
        (availability is Map &&
            [
              'pitch',
              'pronunciation',
              'fillers',
            ].any((k) => availability[k] == false));
    return partial
        ? 'Partial assessment: detailed scoring evidence is unavailable for this legacy session.'
        : 'Legacy assessment: completeness and scoring evidence were not recorded.';
  }
  final availability = raw['availability'];
  final fallback = raw['fallback'];
  final weights = raw['weights'];
  final clarity = weights is Map ? weights['clarity'] : null;
  if (availability is! Map || fallback is! Map || clarity is! Map) {
    return 'Assessment evidence unavailable.';
  }
  final lines = <String>[
    raw['completeness'] == 'complete'
        ? 'Complete assessment.'
        : 'Partial assessment: some evidence is unavailable, uncertain, or incomplete.',
    if (session['status'] == 'Completed')
      'Processing completed; component completeness is reported separately.',
    if (session['analysisValid'] == true) 'Analysis passed usability checks.',
    'Overall weighting: pace 35%, clarity 40%, energy 25%. Displayed to one decimal place.',
  ];
  final basis = raw['basis'];
  final scores = raw['scores'];
  if (scores is Map && scores['articulation'] is num) {
    lines.add(
      'Clarity input: articulation score ${overallScoreText(scores['articulation'])}/100.'
      '${scores['filler_words'] is num ? ' Filler score ${overallScoreText(scores['filler_words'])}/100.' : ''}',
    );
  }
  if (clarity['articulation'] == 1 && clarity['fillers'] == 0) {
    lines.add(
      'Clarity uses articulation only; filler scoring was unavailable.',
    );
  } else if (clarity['articulation'] == .6 && clarity['fillers'] == .4) {
    lines.add(
      'Clarity uses articulation (60%) and accepted filler-span scoring (40%).',
    );
  }
  if (availability['pronunciation'] != true) {
    if (fallback['pronunciation'] == true &&
        availability['enunciation'] == true) {
      lines.add(
        basis is Map && basis['enunciationEvidence'] == 'timing_only'
            ? 'Articulation uses an enunciation timing proxy; word audibility was not measured.'
            : 'Articulation uses the available enunciation timing/audibility proxy.',
      );
    }
  } else {
    lines.add(
      'Pronunciation evidence is an ASR-confidence proxy, not phoneme-level accuracy.',
    );
  }
  if (availability['pitch'] != true) {
    lines.add(
      'Pitch analysis unavailable; energy uses recorded intensity rules and available pause evidence. Intonation cannot be concluded.',
    );
  } else {
    lines.add(
      'Energy uses intensity/pitch rules and available pause evidence.',
    );
  }
  if (availability['intensity'] != true) {
    lines.add('Intensity evidence unavailable.');
  }
  if (availability['pauses'] != true) lines.add('Pause scoring unavailable.');
  if (availability['enunciation'] != true) {
    lines.add('Enunciation evidence unavailable.');
  }
  if (availability['pacing'] != true) {
    lines.add(
      'Pacing measurement unavailable; the stored fallback score is retained.',
    );
  }
  if (raw['coverage'] != 'matched') {
    lines.add('Transcript coverage is incomplete or unverified.');
  }
  if (basis is Map && basis['pacing'] == 'reference') {
    lines.add(
      'Reference-based assessment: pace is compared with reference speed; articulation and energy may include recorded reference adjustments.',
    );
  }
  return lines.join('\n');
}
